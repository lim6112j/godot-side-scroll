# 《엄마에게》 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 새끼 물범이 점프와 꼬리치기로 위험을 넘어 엄마에게 도착하는 5레벨 횡스크롤 게임을 Godot 4.7.2로 구현한다.

**Architecture:** 캐릭터는 피벗 노드 + 시각 슬롯 구조로 조립하고 `AnimationPlayer`가 피벗 프로퍼티만 조작한다. 그래서 도형에서 PNG 스프라이트로 교체할 때 스크립트와 애니메이션 파일을 한 줄도 고치지 않는다. 레벨은 `LevelData` 리소스 5개를 시드 기반 생성기가 배치하는 데이터 주입 방식이라, 설계의 난이도 표가 그대로 난이도 곡선이 된다.

**Tech Stack:** Godot 4.7.2, GDScript, 자체 headless 테스트 하네스 (외부 의존성 없음)

**Spec:** `docs/superpowers/specs/2026-11-09-baby-seal-reach-mom-design.md`

## Global Constraints

아래 값은 설계 문서에서 그대로 옮긴 것이다. 모든 태스크의 요구사항에는 이 섹션이 암시적으로 포함된다.

- 엔진: Godot 4.7.2, `/Applications/Godot.app/Contents/MacOS/Godot`. **GDScript only.** C# 금지 (표준 빌드, mono 미포함).
- 뷰포트: **640×360**, 16:9, stretch mode `canvas_items`, 정수 배율 확대. 60fps 유지.
- 입력 맵은 `project.godot`의 Input Map에 등록한다. 스크립트에 키 이름을 하드코딩하지 않는다.
  - 이동 `←` `→` / `A` `D`, 점프 `Space` / `W` / `↑`, 꼬리치기 `J` / `Z`, 재시도 `R`, 일시정지 `Esc`
- 이동 상수 (설계 5.1): `GRAVITY 900.0`, `JUMP_VELOCITY -320.0`, `JUMP_CUT 0.45`, `MAX_SPEED 130.0`, `ACCEL 900.0`, `GROUND_FRICTION 600.0`, `AIR_ACCEL_RATIO 0.6`, `COYOTE_TIME 0.10`, `JUMP_BUFFER 0.12`
- 꼬리치기 상수 (설계 5.2): `SWAT_DURATION 0.15`, `SWAT_COOLDOWN 0.40`, `SWAT_KNOCKBACK 220.0`, `SWAT_RECOIL -150.0`, `SWAT_PUSH 40.0`, 판정 범위 정면 부채 반경 44px·수직 32px
- **좌표계: Godot 2D에서 y+는 아래쪽이다.** 위로 띄우는 모든 속도는 음수. `JUMP_VELOCITY -320.0`, `SWAT_RECOIL -150.0`이 이 때문이다.
- 체력: 하트 3, `MAX_HEARTS 3`. 피격 시 넉백 + 무적 1.2초. 부활은 항상 마지막 체크포인트.
- 모든 레벨의 목표는 동일하다: 오른쪽 끝의 엄마에게 도착.
- 물고기는 클리어 조건에 절대 넣지 않는다. 표시 전용이다.
- 게임 로직은 `VisualSlot`의 자식을 절대 알지 못한다. 애니메이션은 피벗 프로퍼티만 조작한다.
- 사망 시 씬을 리로드하지 않는다. 플레이어 위치·체력·파괴된 오브젝트만 리셋한다.
- 커밋 단계는 사용자가 명시적으로 요청할 때만 실행한다. 이 환경에서는 커밋 전 승인이 필요하다.
- 테스트 명령: `bash tools/test.sh`. 이 래퍼는 프로젝트 스캔을 강제로 수행한 뒤(`godot --headless --path . --import`, 멱등·약 2초) headless 러너를 실행한다. 원시 명령을 직접 쓰지 않는다 — 씬을 직접 지정해 실행하면 프로젝트 스캔이 생략되어 `class_name` 전역 클래스가 등록되지 않아 클린 체크아웃과 캐시 stale 상태에서 parse error가 난다.

## Review Focus

1. **꼬리치기 없이 레벨 2를 클리어할 수 있다.** 게임의 핵심 전제가 깨지는 것. → Task 7 검증 항목에 테스트.
2. **부활 직후 밀려오는 빙산이 플레이어를 덮쳐 죽음이 무한 반복한다.** → Task 13에 테스트.
3. **그림 교체 시 스크립트나 애니메이션 파일을 고쳐야 한다.** 피벗 구조가 잘못된 것. → Task 3, Task 14에 테스트.
4. **사망 후 씬 리로드로 적이 전부 되살아나 클리어 불가 구간이 생긴다.** → Task 5에 테스트.
5. **평면 틈이 92px를 넘어 점프만으로 건널 수 없다.** → Task 7에 테스트.

## File Structure

```
project.godot                              Autoload(GameState, LevelRegistry), Input Map, 640×360
scenes/
  main.tscn                                게임 진입, 레벨 로드·전환
  ui/title.tscn  hud.tscn  level_complete.tscn  game_over.tscn
  entities/seal_baby.tscn  seal_mom.tscn
  entities/enemy_seagull.tscn  enemy_crab.tscn
  entities/hazard_thin_ice.tscn  hazard_icicle.tscn  hazard_water.tscn  hazard_ice_block.tscn
  entities/pickup_fish.tscn  iceberg.tscn
  level/level.tscn                         지형 컨테이너 + 스포너
resources/levels/level_1.tres ... level_5.tres
scripts/
  autoload/game_state.gd                   체력·물고기·레벨 인덱스·씬 전환
  autoload/level_registry.gd               LevelData 로드와 순서
  seal_baby.gd                             이동·피격 상태 머신
  seal_swat.gd                             꼬리치기 판정·쿨다운·반동
  seal_anim.gd                             애니메이션 이름 → AnimationPlayer
  enemy_seagull.gd  enemy_crab.gd
  hazard_thin_ice.gd  hazard_icicle.gd
  pickup_fish.gd  seal_mom.gd  iceberg.gd
  level_data.gd  level_generator.gd  camera_follow.gd
tests/
  test_runner.tscn  test_runner.gd         headless 진입점
  test_helper.gd                           check() / approx() / 섹션 카운터
  test_movement.gd  test_swat.gd ...        태스크마다 하나씩 추가
tools/prepare_sprites.sh                   PNG 후처리 (Task 14)
```

생성 규칙: 한 파일은 한 가지 책임만 진다. `seal_baby.gd`는 이동과 피격, `seal_swat.gd`는 꼬리치기 판정. 같이 바뀌는 파일은 같이 둔다.

---

### Task 1: 프로젝트 스캐폴드 + headless 테스트 하네스

**Files:**
- Create: `project.godot`
- Create: `tests/test_runner.tscn`
- Create: `tests/test_runner.gd`
- Create: `tests/test_helper.gd`
- Create: `tests/test_smoke.gd`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces:
  - `TestHelper` (class_name, extends RefCounted): `section(name: String) -> void`, `check(condition: bool, name: String) -> void`, `approx(a: float, b: float, tolerance: float, name: String) -> void`, `step_frames(tree: SceneTree, count: int) -> void` (코루틴, `await tree.physics_frame` 반복), `passed() -> bool`, `summary() -> String`
  - 테스트 스위트 규약: `tests/test_*.gd` 는 `RefCounted`를 확장하고 `func run(t: TestHelper) -> void` 를 가진다. `test_runner.gd`와 `test_helper.gd`는 제외하고 자동 발견한다.
  - 입력 액션 이름: `move_left`, `move_right`, `jump`, `swat`, `retry`, `pause`
- Autoload는 이 태스크에서 만들지 않는다. `GameState`는 Task 5, `LevelRegistry`는 Task 6에서 등록한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_smoke.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    t.check(true, "하네스가 실행된다")
    t.check(Engine.get_main_loop() != null, "메인 루프가 존재한다")
    t.check(ClassDB.class_exists("CharacterBody2D"), "물리 노드가 사용 가능하다")
    t.check(ClassDB.class_exists("AnimationPlayer"), "AnimationPlayer가 사용 가능하다")
    t.check(ProjectSettings.get_setting("display/window/size/viewport_width") == 640, "뷰포트 너비 640")
    t.check(ProjectSettings.get_setting("display/window/size/viewport_height") == 360, "뷰포트 높이 360")
    t.check(InputMap.has_action("jump"), "입력 액션 jump가 등록돼 있다")
    t.check(InputMap.has_action("swat"), "입력 액션 swat이 등록돼 있다")
    t.check(InputMap.has_action("move_left"), "입력 액션 move_left가 등장돼 있다")
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn
```

Expected: 프로젝트가 없어 실행 자체가 실패한다 (스크립트/씬을 찾지 못함).

- [ ] **Step 3: 프로젝트와 하네스 구현**

`project.godot`: `config_version=5`, 렌더러 `gl_compatibility`, `display/window/size/viewport_width=640`, `viewport_height=360`, `display/window/stretch/mode="canvas_items"`, `display/window/stretch/aspect="keep"`. Input Map에 6개 액션 등록 (`move_left`: Arrow Left·A / `move_right`: Arrow Right·D / `jump`: Space·W·Arrow Up / `swat`: J·Z / `retry`: R / `pause`: Escape). 에디터의 Input Map으로 등록하거나 섹션을 직접 author한다.

`tests/test_helper.gd`:

```gdscript
class_name TestHelper
extends RefCounted

var failures: Array[String] = []
var total: int = 0
var section_counts: Dictionary = {}
var _section: String = ""

func section(name: String) -> void:
    _section = name

func check(condition: bool, name: String) -> void:
    total += 1
    section_counts[_section] = int(section_counts.get(_section, 0)) + 1
    if not condition:
        failures.append("%s :: %s" % [_section, name])

func approx(a: float, b: float, tolerance: float, name: String) -> void:
    check(absf(a - b) <= tolerance, "%s (기대 %f, 실제 %f)" % [name, b, a])

func step_frames(tree: SceneTree, count: int) -> void:
    for _i in count:
        await tree.physics_frame

func passed() -> bool:
    return failures.is_empty()

func summary() -> String:
    var detail := ""
    for s in section_counts:
        detail += "\n  %s: %d" % [s, section_counts[s]]
    if passed():
        return "ALL %d CHECKS PASSED%s" % [total, detail]
    var lines := "FAILED %d of %d CHECKS:%s" % [failures.size(), total, detail]
    for f in failures:
        lines += "\n  FAIL: " + f
    return lines
```

`tests/test_runner.gd` (루트 노드에 붙임):

```gdscript
extends Node

func _ready() -> void:
    var t := TestHelper.new()
    var dir := DirAccess.open("res://tests")
    for file in dir.get_files():
        if not (file.begins_with("test_") and file.ends_with(".gd")):
            continue
        if file == "test_runner.gd" or file == "test_helper.gd":
            continue
        var script: GDScript = load("res://tests/" + file)
        var suite: Object = script.new()
        if suite.has_method("run"):
            t.section(file)
            await suite.run(t)
    print(t.summary())
    get_tree().quit(1 if not t.passed() else 0)
```

`tests/test_runner.tscn`: 루트 `Node` 하나에 `test_runner.gd`를 붙인 씬.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `smoke: 12` = `ALL 12 CHECKS PASSED`, `exit=0`.

이 단계가 실패하면 하네스 방식 자체를 고친다. 이 태스크가 이후 모든 태스크의 기반이므로, 여기서 확실히 녹색으로 만든 뒤 진행한다.

- [ ] **Step 5: 커밋**

```bash
git add project.godot tests/
git commit -m "chore: scaffold project and headless test harness"
```

사용자 승인 후 실행.

---

### Task 2: 물범 이동 물리

**Files:**
- Create: `scenes/entities/seal_baby.tscn`
- Create: `scripts/seal_baby.gd`
- Create: `tests/test_movement.gd`

**Interfaces:**
- Consumes: Task 1의 입력 액션 `move_left`, `move_right`, `jump`; `TestHelper.step_frames`
- Produces: `BabySeal` (class_name, extends CharacterBody2D)
  - `var facing: int = 1`
  - `signal landed`
  - `func get_horizontal_speed() -> float`
  - `func is_coyote_active() -> bool`
  - `func is_jump_buffered() -> bool`
  - `func set_test_floor(enabled: bool) -> void` — 테스트에서 지면 접촉을 강제로 만든다
  - 이동은 `_physics_process(delta)` 안에서 `velocity`를 직접 계산한다

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_movement.gd`:

```gdscript
extends RefCounted

const GRAVITY := 900.0
const JUMP_VELOCITY := -320.0

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # 중력만 작동
    var v0: float = seal.velocity.y
    await t.step_frames(tree, 10)
    t.approx(seal.velocity.y, v0 + GRAVITY * (1.0 / 60.0) * 10, 2.0, "중력이 누적된다")

    # 지면 고정 후 점프
    seal.set_test_floor(true)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)
    t.check(seal.is_on_floor(), "지면에 닿아 있다")

    Input.action_press("jump")
    await t.step_frames(tree, 1)
    t.approx(seal.velocity.y, JUMP_VELOCITY, 1.0, "점프 초속 -320")
    t.check(not seal.is_on_floor(), "점프하면 지면을 떠난다")

    # 가변 점프: 떼면 상승 속도 45%
    Input.action_release("jump")
    await t.step_frames(tree, 1)
    t.check(seal.velocity.y > JUMP_VELOCITY * 0.9 and seal.velocity.y < 0.0, "점프키를 떼면 상승이 줄된다")

    # 최대 이동 속도
    seal.velocity = Vector2.ZERO
    Input.action_press("move_right")
    await t.step_frames(tree, 60)
    t.check(seal.get_horizontal_speed() <= 130.0 + 0.01, "최대 속도 130을 넘지 않는다")
    t.check(seal.get_horizontal_speed() > 120.0, "가속 후 속도가 120 이상이다")
    t.check(seal.facing == 1, "오른쪽 이동 시 facing이 1")
    Input.action_release("move_right")

    # 마찰
    var before: float = seal.get_horizontal_speed()
    await t.step_frames(tree, 10)
    t.check(seal.get_horizontal_speed() < before, "입력을 끊으면 감속한다")
    t.check(seal.get_horizontal_speed() >= 0.0, "속도가 음수가 되지 않는다")

    # 코요테 타임
    seal.set_test_floor(false)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 1)
    t.check(seal.is_coyote_active(), "지면을 떠난 직후 코요테가 활성")
    Input.action_press("jump")
    await t.step_frames(tree, 1)
    t.check(seal.velocity.y < 0.0, "코요테 중 점프가 통한다")
    Input.action_release("jump")

    seal.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `seal_baby.tscn`을 찾지 못함.

- [ ] **Step 3: 씬과 스크립트 구현**

`scenes/entities/seal_baby.tscn`: 루트 `CharacterBody2D` 이름 `BabySeal`, `script = seal_baby.gd`. 자식으로 `CollisionShape2D`( capsule 또는 rectangle, 약 48×32 픽셀 크기에 맞춤 ). 이 태스크에서는 파츠를 만들지 않는다.

`scripts/seal_baby.gd` — 시그니처와 상수는 Global Constraints의 5.1 값을 그대로 쓴다:

```gdscript
class_name BabySeal
extends CharacterBody2D

signal landed

const GRAVITY := 900.0
const JUMP_VELOCITY := -320.0
const JUMP_CUT := 0.45
const MAX_SPEED := 130.0
const ACCEL := 900.0
const GROUND_FRICTION := 600.0
const AIR_ACCEL_RATIO := 0.6
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

var facing: int = 1
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _test_floor: bool = false

func get_horizontal_speed() -> float: ...
func is_coyote_active() -> bool: ...
func is_jump_buffered() -> bool: ...
func set_test_floor(enabled: bool) -> void: ...
func _physics_process(delta: float) -> void: ...
```

구현 방향: 입력이 있으면 `facing` 방향으로 `ACCEL`(공중에서는 `ACCEL * AIR_ACCEL_RATIO`) 가속, 수평 속도를 `MAX_SPEED`로 clamp. 입력이 없고 지면에 있으면 `GROUND_FRICTION`으로 감속. `is_on_floor()` 또는 `_test_floor` 가 참이면 `_coyote = COYOTE_TIME`, 아니면 감소. 점프 입력이 들어오면 `_jump_buffer = JUMP_BUFFER`로 리셋, 항상 감소. 버퍼가 살아 있고 (`_coyote > 0`) 이면 점프 발동. 점프 중 점프키를 떼면 `velocity.y *= JUMP_CUT` (한 번만). `_test_floor`는 지면 판정을 강제하는 테스트용 훅이며, 프로덕션 코드 경로에서는 항상 `false`다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `smoke: 12 + movement: 12` = `ALL 24 CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scenes/entities/seal_baby.tscn scripts/seal_baby.gd tests/test_movement.gd
git commit -m "feat: add baby seal movement with coyote time and jump buffer"
```

사용자 승인 후 실행.

---

### Task 3: 물범 퍼펫 구조 + AnimationPlayer

**Files:**
- Create: `scripts/seal_anim.gd`
- Modify: `scenes/entities/seal_baby.tscn`
- Create: `tests/test_puppet.gd`

**Interfaces:**
- Consumes: Task 2의 `BabySeal`
- Produces:
  - 피벗 노드 이름 (정확히 이 문자열): `BodyPivot`, `HeadPivot`, `TailPivot`, `FlipperFrontPivot`, `FlipperBackPivot`
  - 각 피벗의 자식: `VisualSlot` → `PolygonPuppet` → 파츠별 `Polygon2D`
  - `SealAnim` (class_name, extends Node, `seal_baby.tscn`의 자식): `play(name: String) -> void`, `current() -> String`, `has(name: String) -> bool`
  - 애니메이션 이름 (정확히): `idle`, `run`, `jump`, `fall`, `swat`, `hurt`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_puppet.gd`:

```gdscript
extends RefCounted

const ANIMS := ["idle", "run", "jump", "fall", "swat", "hurt"]
const PIVOTS := ["BodyPivot", "HeadPivot", "TailPivot", "FlipperFrontPivot", "FlipperBackPivot"]

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as Node
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    var anim := seal.get_node_or_null("SealAnim") as SealAnim
    t.check(anim != null, "SealAnim 노드가 존재한다")

    for a in ANIMS:
        t.check(anim.has(a), "애니메이션 %s가 존재한다" % a)

    for p in PIVOTS:
        t.check(seal.get_node_or_null(p) != null, "피벗 %s가 존재한다" % p)
        t.check(seal.get_node_or_null(p + "/VisualSlot") != null, "%s 아래 VisualSlot이 있다" % p)
        t.check(seal.get_node_or_null(p + "/VisualSlot/PolygonPuppet") != null, "%s 아래 PolygonPuppet이 있다" % p)

    # 그림 교체 안전성: 어떤 트랙도 VisualSlot 하위를 겨냥하지 않는다
    var player := seal.get_node_or_null("SealAnim/AnimationPlayer") as AnimationPlayer
    t.check(player != null, "AnimationPlayer가 존재한다")
    var leaks: Array[String] = []
    for a in ANIMS:
        if not player.has_animation(a):
            continue
        var anim_res := player.get_animation(a)
        for i in anim_res.get_track_count():
            var path: String = anim_res.track_get_path(i)
            if "/VisualSlot/" in path or path.contains("PolygonPuppet"):
                leaks.append("%s -> %s" % [a, path])
    t.check(leaks.is_empty(), "어떤 애니메이션 트랙도 VisualSlot 하위를 겨냥하지 않는다: %s" % str(leaks))

    # 재생과 실제 변형
    anim.play("run")
    t.check(anim.current() == "run", "play 후 current가 run")
    var body := seal.get_node("BodyPivot") as Node2D
    var scale_before: Vector2 = body.scale
    await t.step_frames(tree, 20)
    t.check(body.scale != scale_before, "애니메이션이 BodyPivot 스케일을 실제로 변화시킨다")

    anim.play("idle")
    var tail := seal.get_node("TailPivot") as Node2D
    var rot_before: float = tail.rotation
    await t.step_frames(tree, 20)
    t.check(absf(tail.rotation - rot_before) > 0.001, "애니메이션이 TailPivot 회전을 실제로 변화시킨다")

    seal.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `SealAnim`과 피벗 노드들을 찾지 못함.

- [ ] **Step 3: 씬과 스크립트 구현**

`scenes/entities/seal_baby.tscn`에 추가: `SealAnim`(`Node`) → `AnimationPlayer`. 그리고 `BodyPivot`, `HeadPivot`, `TailPivot`, `FlipperFrontPivot`, `FlipperBackPivot` 다섯 `Node2D`를 `BabySeal`의 자식으로 둔다. 각 피벗 아래 `VisualSlot`(`Node2D`) → `PolygonPuppet`(`Node2D`) → 파츠별 `Polygon2D`.

피벗 위치는 설계 7.1 값을 쓴다: `HeadPivot` (0, -18), `TailPivot` (-20, 4), `FlipperFrontPivot` (6, 2), `FlipperBackPivot` (4, 2), `BodyPivot` (0, 0).

도형 파츠는 `png-prompts.md` 4.1표의 인게임 크기를 만족하는 범위에서 자유롭게 그린다. 팔레트는 `png-prompts.md` 1장의 hex를 쓴다.

`scripts/seal_anim.gd`:

```gdscript
class_name SealAnim
extends Node

@onready var _player: AnimationPlayer = $AnimationPlayer

func play(name: String) -> void:
    if has(name):
        _player.play(name)

func current() -> String:
    return _player.current_animation

func has(name: String) -> bool:
    return _player.has_animation(name)
```

애니메이션 6개를 만든다. 트랙 타겟은 **피벗 프로퍼티만**: `BodyPivot:scale`, `BodyPivot:position`, `HeadPivot:rotation`, `HeadPivot:position`, `TailPivot:rotation`, `TailPivot:position`, `FlipperFrontPivot:rotation`, `FlipperBackPivot:rotation`. `VisualSlot`이나 파츠 노드를 겨냥하는 트랙을 만들지 않는다. 내용은 설계 7.3 표를 따른다. 길이 0.3~0.5초. `swat`, `hurt`는 원샷, 나머지는 루프.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `smoke: 12 + movement: 12 + puppet: 27` = `ALL 51 CHECKS PASSED`, `exit=0`.

트랙 누수 검사(`VisualSlot` 미경유)가 이 설계의 핵심 보증이다. 여기서 실패하면 그림 교체가 스크립트 수정을 요구하게 된다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/seal_anim.gd scenes/entities/seal_baby.tscn tests/test_puppet.gd
git commit -m "feat: assemble baby seal as pivot puppet with swap-safe animations"
```

사용자 승인 후 실행.

---

### Task 4: 꼬리치기

**Files:**
- Create: `scripts/seal_swat.gd`
- Modify: `scenes/entities/seal_baby.tscn`
- Modify: `scripts/seal_baby.gd`
- Create: `tests/test_swat.gd`

**Interfaces:**
- Consumes: Task 2의 `BabySeal`, Task 3의 `SealAnim`
- Produces: `SealSwat` (class_name, extends Node, `seal_baby.tscn`의 자식 노드 이름 `SealSwat`)
  - `signal swat_hit(target: Node)`
  - `func try_swat() -> bool` — 쿨다운 중이면 `false`
  - `func is_active() -> bool` — 0.15초 활성 구간
  - `func is_on_cooldown() -> bool`
  - `func get_hitbox() -> Area2D` — 판정 영역. 활성/비활성은 `monitoring`으로 제어
- `BabySeal`에 추가: `func try_swat() -> void` (SealSwat에 위임하고, 히트 시 반동 적용)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_swat.gd`:

```gdscript
extends RefCounted

const SWAT_RECOIL := -150.0

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)
    var swat := seal.get_node_or_null("SealSwat") as SealSwat
    t.check(swat != null, "SealSwat 노드가 존재한다")

    t.check(not swat.is_active(), "시작 시 비활성")
    t.check(not swat.is_on_cooldown(), "시작 시 쿨다운 아님")

    # 시동
    t.check(swat.try_swat(), "첫 꼬리치기가 통한다")
    t.check(swat.is_active(), "시동 직후 활성")
    t.check(not swat.try_swat(), "쿨다운 중 재시동이 거부된다")

    # 활성 시간 0.15초 ≈ 9프레임
    await t.step_frames(tree, 6)
    t.check(swat.is_active(), "0.10초 경과 후에도 활성")
    await t.step_frames(tree, 6)
    t.check(not swat.is_active(), "0.20초 경과 후 비활성")

    # 쿨다운 0.40초 ≈ 24프레임
    await t.step_frames(tree, 10)
    t.check(swat.is_on_cooldown(), "0.30초 경과 후 쿨다운 중")
    await t.step_frames(tree, 8)
    t.check(not swat.is_on_cooldown(), "0.40초 경과 후 쿨다운 종료")
    t.check(swat.try_swat(), "쿨다운 종료 후 재시동 가능")

    # 공중 사용 가능
    seal.velocity = Vector2(0, -100)
    swat.try_swat()
    t.check(swat.is_active(), "공중에서도 꼬리치기가 활성화된다")

    # 반동: 히트 시 위로 150px/s
    # StaticBody2D를 쓴다. Area2D는 body_entered를 발생시키지 못한다.
    # 먼저 쿨다운(0.40초 = 24프레임)을 만료시킨다.
    await t.step_frames(tree, 25)
    seal.global_position = Vector2.ZERO
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 1)

    var hits: Array[Node] = []
    swat.swat_hit.connect(func(target: Node) -> void: hits.append(target))
    var dummy := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(24, 24)
    shape.shape = rect
    dummy.add_child(shape)
    dummy.add_to_group("swat_target")
    tree.root.add_child(dummy)
    dummy.global_position = swat.get_hitbox().global_position

    t.check(swat.try_swat(), "쿨다운 만료 후 재시동이 통한다")
    await t.step_frames(tree, 1)
    t.check(hits.size() > 0, "히트가 감지된다")
    # y+는 아래. 위로 띄우므로 음수. 중력이 1프레임분 더해지므로 하한만 확인한다.
    t.check(seal.velocity.y <= SWAT_RECOIL + 1.0,
        "히트 시 위로 150px/s 반동 (실제 %f)" % seal.velocity.y)

    dummy.queue_free()
    seal.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `SealSwat` 노드를 찾지 못함.

- [ ] **Step 3: 구현**

`scenes/entities/seal_baby.tscn`에 추가: `SealSwat`(`Node`, 스크립트 `seal_swat.gd`)과 그 자식 `SwatHitbox`(`Area2D` + `CollisionShape2D`, 정면 부채 반경 44px·수직 32px에 맞춤, `monitoring = false` 기본).

`scripts/seal_swat.gd`:

```gdscript
class_name SealSwat
extends Node

signal swat_hit(target: Node)

const DURATION := 0.15
const COOLDOWN := 0.40

var _active: float = 0.0
var _cooldown: float = 0.0

@onready var _hitbox: Area2D = $SwatHitbox

func try_swat() -> bool: ...
func is_active() -> bool: ...
func is_on_cooldown() -> bool: ...
func get_hitbox() -> Area2D: ...
func _physics_process(delta: float) -> void: ...
func _on_body_entered(body: Node) -> void: ...
```

구현 방향: `try_swat()`는 `_cooldown > 0` 이면 `false`. 아니면 `_active = DURATION`, `_cooldown = COOLDOWN`, `_hitbox.monitoring = true`로 두고 `true`. `_physics_process`에서 `_active`와 `_cooldown`을 감소시키고, `_active`가 0에 도달하면 `monitoring = false`. 히트는 `Area2D.body_entered`로 받되, 대상이 `swat_target` 그룹에 있을 때 `swat_hit`을 발생시킨다. 같은 시전에서 한 대상은 한 번만 친다.

`scripts/seal_baby.gd`에 추가: `func try_swat() -> void`. `SealSwat.swat_hit`을 구독해 히트가 나면 `velocity.y = SWAT_RECOIL`를 설정한다(반동). 꼬리치기 발동 시 `SealAnim.play("swat")`을 호출한다. 공중에서 꼬리치기를 쓰면 `velocity.x += facing * SWAT_PUSH`를 더한다. 지면에서 쓰면 0.15초간 마찰을 3배로 올려 제동 효과를 준다(설계 5.2).

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + movement: 12 + puppet: 27 + swat: 21` = `ALL 72 CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/seal_swat.gd scripts/seal_baby.gd scenes/entities/seal_baby.tscn tests/test_swat.gd
git commit -m "feat: add tail swat with cooldown, recoil and knockback"
```

사용자 승인 후 실행.

---

### Task 5: 체력·피격·체크포인트 부활

**Files:**
- Create: `scripts/autoload/game_state.gd`
- Modify: `project.godot` (`GameState` Autoload 등록)
- Modify: `scripts/seal_baby.gd`
- Create: `tests/test_health.gd`

**Interfaces:**
- Consumes: Task 2의 `BabySeal`, Task 4의 `SealSwat`
- Produces: `GameState` (class_name, extends Node, Autoload)
  - `const MAX_HEARTS := 3`
  - `var hearts: int`
  - `var current_level_index: int`
  - `var fish_collected: int`
  - `var fish_total: int`
  - `signal hearts_changed(new_value: int)`
  - `signal player_died`
  - `func lose_heart() -> void`
  - `func collect_fish() -> void`
  - `func is_dead() -> bool`
  - `func reset_for_level() -> void` — `hearts = MAX_HEARTS`, `fish_collected = 0`
- `BabySeal`에 추가: `signal died`, `var is_invulnerable: bool`, `func take_hit(from_position: Vector2) -> void`, `func respawn_at(position: Vector2) -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_health.gd`:

```gdscript
extends RefCounted

const INVULNERABLE := 1.2

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    GameState.reset_for_level()
    t.check(GameState.hearts == 3, "시작 하트 3")
    t.check(not GameState.is_dead(), "시작 시 살아있다")

    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # 피격 1회
    seal.take_hit(Vector2(100, 0))
    t.check(GameState.hearts == 2, "피격 시 하트 2")
    t.check(seal.is_invulnerable, "피격 시 무적 진입")

    # 무적 중 재피격 무시
    await t.step_frames(tree, 12)
    seal.take_hit(Vector2(100, 0))
    t.check(GameState.hearts == 2, "무적 중 재피격이 무시된다")

    # 무적 종료
    await t.step_frames(tree, 60)
    t.check(not seal.is_invulnerable, "1.2초 후 무적 종료")

    # 하트 0 → 사망
    GameState.lose_heart()
    GameState.lose_heart()
    t.check(GameState.is_dead(), "하트 0이면 사망")

    # 부활
    var spawn := Vector2(500, 100)
    seal.respawn_at(spawn)
    t.check(GameState.hearts == 3, "부활 시 하트 3 복원")
    t.check(seal.global_position.distance_to(spawn) < 1.0, "부활 위치로 이동한다")
    t.check(not seal.is_invulnerable, "부활 시 무적이 아니다")
    t.check(seal.is_inside_tree(), "부활해도 같은 인스턴스를 유지한다 (씬 리로드 없음)")

    # 넉백
    seal.global_position = Vector2.ZERO
    seal.take_hit(Vector2(200, 0))
    t.check(seal.velocity.x < 0.0, "오른쪽에서 피격하면 왼쪽으로 넉백")

    seal.queue_free()
    GameState.reset_for_level()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `GameState` Autoload가 없음.

- [ ] **Step 3: 구현**

`project.godot`의 `[autoload]` 섹션에 `GameState="*res://scripts/autoload/game_state.gd"` 추가.

`scripts/autoload/game_state.gd`:

```gdscript
class_name GameState
extends Node

const MAX_HEARTS := 3

var hearts: int = MAX_HEARTS
var current_level_index: int = 1
var fish_collected: int = 0
var fish_total: int = 0

signal hearts_changed(new_value: int)
signal player_died

func lose_heart() -> void:
    hearts = maxi(0, hearts - 1)
    hearts_changed.emit(hearts)
    if hearts == 0:
        player_died.emit()

func collect_fish() -> void:
    fish_collected += 1

func is_dead() -> bool:
    return hearts <= 0

func reset_for_level() -> void:
    hearts = MAX_HEARTS
    fish_collected = 0
    hearts_changed.emit(hearts)
```

`scripts/seal_baby.gd`에 추가: `take_hit(from_position)`. `is_invulnerable`이 참이면 무시. 아니면 `is_invulnerable = true`, `GameState.lose_heart()` 호출, 넉백(`from_position`이 오른쪽에 있으면 왼쪽으로 180px/s, 위로 120px/s), `SealAnim.play("hurt")`, `INVULNERABLE_TIME`(1.2초) 타이머를 `_physics_process`에서 감소시켜 0이 되면 해제. `respawn_at(position)`: `global_position = position`, `velocity = Vector2.ZERO`, `GameState.reset_for_level()`, `is_invulnerable = false`. 씬을 리로드하지 않고 인스턴스를 유지한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + puppet: 27 + swat: 21 + health: 12` = `ALL 84 CHECKS PASSED`, `exit=0`.

"부활해도 같은 인스턴스를 유지한다" 검사가 설계의 씬 리로드 금지 규칙을 고정한다. 여기서 리로드 방식으로 가면 적이 전부 되살아나는 버그가 생긴다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/autoload/game_state.gd project.godot scripts/seal_baby.gd tests/test_health.gd
git commit -m "feat: add hearts, damage and checkpoint respawn without scene reload"
```

사용자 승인 후 실행.

---

### Task 6: LevelData 5종

**Files:**
- Create: `scripts/level_data.gd`
- Create: `resources/levels/level_1.tres` ~ `level_5.tres`
- Create: `tests/test_level_data.gd`

**Interfaces:**
- Consumes: 없음
- Produces: `LevelData` (class_name, extends Resource) — 필드는 설계 8장과 동일:
  `level_index: int`, `length_px: float`, `flat_max_gap_px: float`, `recoil_max_gap_px: float`, `enemy_density: float`, `hazard_count: int`, `checkpoint_count: int`, `enemy_mix: Array[String]`, `allows_thin_ice: bool`, `allows_icicle: bool`, `allows_water: bool`, `has_time_pressure: bool`, `swat_wall_count: int`, `recoil_gap_count: int`, `seed_value: int`
- 공개 상수 `const MAX_FLAT_GAP := 92.0` (설계 8.3의 평면 점프 최대 거리)

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_level_data.gd`:

```gdscript
extends RefCounted

const LENGTHS := [2400.0, 3000.0, 3600.0, 4200.0, 4800.0]
const DENSITY := [2.0, 4.0, 6.0, 8.0, 10.0]
const HAZARDS := [1, 3, 5, 8, 11]
const CHECKPOINTS := [2, 2, 2, 1, 1]
const FLAT_GAPS := [90.0, 90.0, 92.0, 92.0, 92.0]
const RECOIL_GAPS := [0.0, 0.0, 130.0, 150.0, 170.0]

func run(t: TestHelper) -> void:
    for i in 5:
        var path := "res://resources/levels/level_%d.tres" % (i + 1)
        var res := load(path) as LevelData
        t.check(res != null, "레벨 %d 리소스가 로드된다" % (i + 1))
        if res == null:
            continue
        t.check(res.level_index == i + 1, "레벨 %d 인덱스가 %d" % [i + 1, i + 1])
        t.approx(res.length_px, LENGTHS[i], 0.01, "레벨 %d 길이" % (i + 1))
        t.approx(res.enemy_density, DENSITY[i], 0.01, "레벨 %d 적 밀도" % (i + 1))
        t.check(res.hazard_count == HAZARDS[i], "레벨 %d 위험 지형 수" % (i + 1))
        t.check(res.checkpoint_count == CHECKPOINTS[i], "레벨 %d 체크포인트 수" % (i + 1))
        t.approx(res.flat_max_gap_px, FLAT_GAPS[i], 0.01, "레벨 %d 평면 최대 틈" % (i + 1))
        t.approx(res.recoil_max_gap_px, RECOIL_GAPS[i], 0.01, "레벨 %d 반동 필요 최대 틈" % (i + 1))

        # 평면 틈은 반드시 92 이하 (점프만으로 건너야 한다)
        t.check(res.flat_max_gap_px <= LevelData.MAX_FLAT_GAP + 0.01,
            "레벨 %d 평면 틈이 92 이하다" % (i + 1))

        # 꼬리치기 강제: L1은 0, L2~L5는 1 이상
        var forced: int = res.swat_wall_count + res.recoil_gap_count
        if i == 0:
            t.check(forced == 0, "레벨 1에 꼬리치기 강제 수단이 없다")
        else:
            t.check(forced >= 1, "레벨 %d에 꼬리치기 강제 수단이 있다" % (i + 1))

        # 시간 압박은 레벨 5만
        t.check(res.has_time_pressure == (i == 4), "레벨 %d 시간 압박 설정" % (i + 1))

    var l1 := load("res://resources/levels/level_1.tres") as LevelData
    t.check(l1.enemy_mix == ["crab"], "레벨 1 적 구성이 게만")
    t.check(not l1.allows_icicle, "레벨 1에 고드름 없음")
    var l5 := load("res://resources/levels/level_5.tres") as LevelData
    t.check(l5.allows_icicle, "레벨 5에 고드름 있음")
    t.check(l5.allows_water, "레벨 5에 물 있음")
    t.check(l5.enemy_mix.has("seagull"), "레벨 5에 갈매기 있음")
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `LevelData` 클래스를 찾지 못함.

- [ ] **Step 3: 구현**

`scripts/level_data.gd`: 설계 8장의 필드 선언을 그대로 옮기고, `const MAX_FLAT_GAP := 92.0`을 둔다.

`resources/levels/level_N.tres` 5개. 값은 설계 6장 표와 아래 규칙을 쓴다:

| 레벨 | length | flat_gap | recoil_gap | density | hazard | checkpoint | swat_wall | recoil_gap | enemy_mix | thin_ice | water | icicle | pressure | seed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2400 | 90 | 0 | 2 | 1 | 2 | 0 | 0 | ["crab"] | true | false | false | false | 101 |
| 2 | 3000 | 90 | 0 | 4 | 3 | 2 | 2 | 0 | ["crab"] | true | false | false | false | 202 |
| 3 | 3600 | 92 | 130 | 6 | 5 | 2 | 2 | 2 | ["crab","seagull"] | true | false | false | false | 303 |
| 4 | 4200 | 92 | 150 | 8 | 8 | 1 | 3 | 3 | ["crab","seagull"] | true | true | false | false | 404 |
| 5 | 4800 | 92 | 170 | 10 | 11 | 1 | 4 | 4 | ["crab","seagull"] | true | true | true | true | 505 |

`allows_thin_ice`는 전 레벨 `true`. 레벨 1의 위험 지형 1개는 얇은 얼음이다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + swat: 21 + health: 12 + level_data: 60` = `ALL 144 CHECKS PASSED`, `exit=0`.

"레벨 1에 꼬리치기 강제 수단이 없다"와 "레벨 2~5에는 있다" 두 검사가 설계의 안티목표를 데이터 수준에서 고정한다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/level_data.gd resources/levels/ tests/test_level_data.gd
git commit -m "feat: add five LevelData resources encoding the difficulty curve"
```

사용자 승인 후 실행.

---

### Task 7: 레벨 생성기

**Files:**
- Create: `scripts/level_generator.gd`
- Create: `scripts/autoload/level_registry.gd`
- Modify: `project.godot` (`LevelRegistry` Autoload 등록)
- Create: `scenes/level/level.tscn`
- Create: `tests/test_generator.gd`

**Interfaces:**
- Consumes: Task 6의 `LevelData`, `MAX_FLAT_GAP`
- Produces:
  - `LevelGenerator` (class_name, extends RefCounted): `func generate(data: LevelData) -> Dictionary`
    - 반환 키: `"root"` (Node2D), `"spawn"` (Vector2), `"checkpoints"` (Array[Vector2]), `"goal_x"` (float), `"fish_total"` (int)
  - `LevelRegistry` (class_name, extends Node, Autoload): `func level_count() -> int`, `func get_level(index: int) -> LevelData`
  - 노드 그룹 (이후 태스크가 사용): `"enemy"`, `"hazard"`, `"swat_target"`, `"checkpoint"`, `"goal"`, `"fish"`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_generator.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var gen := LevelGenerator.new()

    for i in 5:
        var data := LevelRegistry.get_level(i + 1) as LevelData
        t.check(data != null, "레벨 %d 데이터를 레지스트리에서 얻는다" % (i + 1))
        if data == null:
            continue

        var result: Dictionary = gen.generate(data)
        var root := result["root"] as Node2D
        t.check(root != null, "레벨 %d 루트가 생성된다" % (i + 1))
        if root == null:
            continue

        # 평면 틈은 전부 92 이하 (Review Focus 5)
        var gaps: Array = root.get_meta("flat_gaps", [])
        t.check(not gaps.is_empty(), "레벨 %d에 평면 틈이 있다" % (i + 1))
        for g in gaps:
            t.check(float(g) <= LevelData.MAX_FLAT_GAP + 0.01,
                "레벨 %d 평면 틈 %s 가 92 이하" % [i + 1, str(g)])

        # 꼬리치기 강제 수단 개수 (Review Focus 1)
        var walls: int = root.get_meta("swat_wall_count", 0)
        var recoil_gaps: int = root.get_meta("recoil_gap_count", 0)
        t.check(walls == data.swat_wall_count,
            "레벨 %d 얼음 벽 수가 %d (실제 %d)" % [i + 1, data.swat_wall_count, walls])
        t.check(recoil_gaps == data.recoil_gap_count,
            "레벨 %d 반동 틈 수가 %d (실제 %d)" % [i + 1, data.recoil_gap_count, recoil_gaps])

        # recoil_max_gap_px가 0이면 반동 틈을 만들지 않는다
        if data.recoil_max_gap_px <= 0.0:
            t.check(recoil_gaps == 0, "레벨 %d에 반동 틈이 없다" % (i + 1))

        # 반동 틈마다 반동 대상이 앞에 있다
        for info in root.get_meta("recoil_targets", []):
            t.check(info.has("target"), "레벨 %d 반동 틈에 대상이 있다" % (i + 1))

        # 체크포인트
        var cps: Array = result["checkpoints"]
        t.check(cps.size() == data.checkpoint_count,
            "레벨 %d 체크포인트 수가 %d (실제 %d)" % [i + 1, data.checkpoint_count, cps.size()])

        # 스폰과 목표
        t.check((result["spawn"] as Vector2).x < 600.0, "레벨 %d 스폰이 앞부분" % (i + 1))
        var goal_x: float = result["goal_x"]
        t.check(goal_x > data.length_px * 0.9, "레벨 %d 목표가 길이의 90%% 이후" % (i + 1))
        t.check(int(result["fish_total"]) > 0, "레벨 %d에 물고기가 있다" % (i + 1))

        # 결정성
        var again: Dictionary = gen.generate(data)
        t.check((again["spawn"] as Vector2) == (result["spawn"] as Vector2),
            "레벨 %d 생성이 결정적이다 (스폰 일치)" % (i + 1))
        t.check(float(again["goal_x"]) == goal_x, "레벨 %d 생성이 결정적이다 (목표 일치)" % (i + 1))

        root.free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `LevelGenerator` 클래스를 찾지 못함.

- [ ] **Step 3: 구현**

`scripts/autoload/level_registry.gd`:

```gdscript
class_name LevelRegistry
extends Node

const LEVEL_DIR := "res://resources/levels/"

func level_count() -> int:
    return 5

func get_level(index: int) -> LevelData:
    if index < 1 or index > level_count():
        return null
    return load(LEVEL_DIR + "level_%d.tres" % index) as LevelData
```

`project.godot`의 `[autoload]`에 `LevelRegistry="*res://scripts/autoload/level_registry.gd"` 추가.

`scripts/level_generator.gd` — 시그니처:

```gdscript
class_name LevelGenerator
extends RefCounted

func generate(data: LevelData) -> Dictionary: ...
```

구현 방향 (설계 8.1·8.3):

1. `RandomNumberGenerator`를 `data.seed_value`로 시드한다. 같은 데이터는 항상 같은 결과.
2. 지면을 세그먼트로 나눈다. 세그먼트 사이 평면 틈은 `flat_max_gap_px` 이하로 뽑는다. 첫 세그먼트는 600px, 마지막은 400px.
3. 떠 있는 발판을 둔다. 고저차가 있는 발판은 2단 높이(약 48px, 96px)로 배치한다.
4. `swat_wall_count` 개수만큼 얼음 벽을 **레벨 앞 1/3**에 배치한다. 높이 90~110px.
5. `recoil_gap_count` 개수만큼 반동 틈을 **레벨 뒤 2/3**에 배치한다. 틈 앞에 반동 대상(게 또는 작은 얼음 블록)을 함께 놓고, `recoil_targets` 메타에 기록한다.
6. 적을 `enemy_density`로 간격을 계산해 배치한다. 앞 1/3 구간에는 밀도의 30%만.
7. 위험 지형을 `hazard_count` 개수만큼 배치한다. `allows_thin_ice`가 `false`면 얇은 얼음을 쓰지 않는다. 같은 원리로 `allows_water`, `allows_icicle`.
8. 체크포인트를 `checkpoint_count` 개 균등 배치.
9. 마지막 세그먼트 끝에 엄마 빙하를 놓고 `goal_x`를 기록한다.
10. 물고기를 세그먼트마다 1~2개 배치하고 `fish_total`을 기록한다.

루트 `Node2D`에 메타를 붙인다: `"flat_gaps"` (Array[float]), `"swat_wall_count"` (int), `"recoil_gap_count"` (int), `"recoil_targets"` (Array[Dictionary]). 테스트가 이 메타를 읽는다.

`scenes/level/level.tscn`: 루트 `Node2D` 이름 `Level` 하나. 생성기가 만든 `root`를 이 씬의 자식으로 붙이는 용도. 이 태스크에서는 씬을 만들기만 하고, 조립은 Task 10에서 한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + health: 12 + level_data: 60 + generator: 55+` = `ALL 199+ CHECKS PASSED`, `exit=0`.

이 단계의 두 검사가 설계의 핵심 전제를 기계적으로 확인한다: **모든 레벨의 평면 틈이 92px 이하**이고, **레벨 2~5에 꼬리치기 강제 수단이 정확히 명세된 개수만큼** 있다. 둘 중 하나라도 실패하면 게임의 전제가 깨진 것이므로 구현을 고친다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/level_generator.gd scripts/autoload/level_registry.gd project.godot scenes/level/level.tscn tests/test_generator.gd
git commit -m "feat: add seeded level generator driven by LevelData"
```

사용자 승인 후 실행.

---

### Task 8: 적 — 게와 갈매기

**Files:**
- Create: `scripts/enemy_crab.gd`
- Create: `scripts/enemy_seagull.gd`
- Create: `scenes/entities/enemy_crab.tscn`
- Create: `scenes/entities/enemy_seagull.tscn`
- Modify: `scenes/entities/seal_baby.tscn` (`Hurtbox` 추가)
- Modify: `scripts/seal_baby.gd`
- Modify: `scripts/autoload/game_state.gd` (`die()` 추가)
- Create: `tests/test_enemies.gd`

**Interfaces:**
- Consumes: Task 5의 `GameState`, `BabySeal.take_hit`; Task 4의 `swat_target` 그룹
- Produces:
  - `EnemyCrab` (class_name, extends CharacterBody2D): `@export var patrol_range: float = 80.0`, `@export var speed: float = 40.0`, `func _on_swatted() -> void`
  - `EnemySeagull` (class_name, extends CharacterBody2D): `@export var flight_range: float = 200.0`, `@export var speed: float = 90.0`, `func _on_swatted() -> void`
  - `BabySeal`에 추가: `func stomp(enemy: Node) -> void`, 노드 `Hurtbox` (Area2D)
  - `GameState`에 추가: `func die() -> void` — `hearts = 0`, `player_died` 발생

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_enemies.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # 게 순찰
    var crab := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D
    crab.global_position = Vector2(0, 0)
    tree.root.add_child(crab)
    await t.step_frames(tree, 2)
    var x0: float = crab.global_position.x
    await t.step_frames(tree, 60)
    t.check(absf(crab.global_position.x - x0) > 10.0, "게가 이동한다")
    await t.step_frames(tree, 120)
    t.check(absf(crab.global_position.x - x0) <= crab.patrol_range + 1.0,
        "게가 순찰 범위를 벗어나지 않는다")

    # 게를 밟으면 사망
    GameState.reset_for_level()
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)
    seal.stomp(crab)
    t.check(GameState.is_dead(), "게를 밟으면 사망한다")

    # 갈매기 비행
    GameState.reset_for_level()
    var gull := preload("res://scenes/entities/enemy_seagull.tscn").instantiate() as CharacterBody2D
    gull.global_position = Vector2(500, -100)
    tree.root.add_child(gull)
    await t.step_frames(tree, 2)
    var g0: float = gull.global_position.x
    await t.step_frames(tree, 60)
    t.check(absf(gull.global_position.x - g0) > 10.0, "갈매기가 비행한다")
    await t.step_frames(tree, 200)
    t.check(absf(gull.global_position.x - g0) <= gull.flight_range + 1.0,
        "갈매기가 비행 범위를 벗어나지 않는다")

    # 꼬리치기로 제거
    var swatted: Array[Node] = []
    for e in [crab, gull]:
        e.add_to_group("swat_target")
    var swat := seal.get_node("SealSwat") as SealSwat
    swat.swat_hit.connect(func(target: Node) -> void: swatted.append(target))
    seal.global_position = crab.global_position + Vector2(10, 0)
    swat.try_swat()
    await t.step_frames(tree, 2)
    t.check(swatted.has(crab), "게에 꼬리치기가 적중한다")
    t.check(crab.is_queued_for_deletion(), "꼬리치기 맞은 게가 제거된다")
    # 넉백: 게가 물범 왼쪽에 있으므로 음수 방향 (설계 5.2, KNOCKBACK 220)
    t.check(crab.velocity.x < 0.0, "게가 물범 반대편으로 넉백된다")
    t.approx(crab.velocity.x, -SealSwat.KNOCKBACK, 1.0, "넉백 속도 220")

    seal.global_position = gull.global_position + Vector2(10, 0)
    swat.try_swat()
    await t.step_frames(tree, 2)
    t.check(swatted.has(gull), "갈매기에 꼬리치기가 적중한다")
    t.check(gull.is_queued_for_deletion(), "꼬리치기 맞은 갈매기가 제거된다")
    t.check(gull.velocity.x < 0.0, "갈매기가 물범 반대편으로 넉백된다")
    t.approx(gull.velocity.x, -SealSwat.KNOCKBACK, 1.0, "갈매기 넉백 속도 220")

    # 충돌 시 피격
    GameState.reset_for_level()
    var crab2 := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D
    crab2.add_to_group("swat_target")
    crab2.global_position = Vector2(0, 0)
    tree.root.add_child(crab2)
    await t.step_frames(tree, 2)
    seal.global_position = crab2.global_position
    seal.velocity = Vector2(0, 300)   # 아래로 떨어져서 측면 충돌
    await t.step_frames(tree, 3)
    t.check(GameState.hearts < 3, "게와 충돌하면 하트가 준다")

    for n in [crab, gull, crab2, seal]:
        if is_instance_valid(n):
            n.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `enemy_crab.tscn`을 찾지 못함.

- [ ] **Step 3: 구현**

`scripts/autoload/game_state.gd`에 추가:

```gdscript
func die() -> void:
    hearts = 0
    hearts_changed.emit(hearts)
    player_died.emit()
```

`scenes/entities/enemy_crab.tscn`: 루트 `CharacterBody2D` 이름 `EnemyCrab`, 스크립트 `enemy_crab.gd`. 자식으로 `CollisionShape2D` (약 32×24)와 `AnimatedSprite2D` 대신 **임시 `Polygon2D` 도형** (그림은 Task 14에서 교체). `swat_target` 그룹에 속하게 한다.

**물범은 `player` 그룹에 속해야 한다.** `_on_swatted()`가 넉백 방향을 구할 때 `get_tree().get_first_node_in_group("player")`로 시전자를 찾기 때문이다. `seal_baby.gd`의 `_ready()`에 `add_to_group("player")` 한 줄을 추가한다.

**넉백은 반드시 적용한다.** `SealSwat.KNOCKBACK`(220.0)은 설계 5.2의 세 가지 꼬리치기 효과 중 하나이며, Task 4 리뷰에서 "선언만 있고 아무도 읽지 않는 상수"로 지적됐다. `_on_swatted()`가 `queue_free()` 전에 `velocity.x = dir * SealSwat.KNOCKBACK`을 적용해야 한다.

`scripts/enemy_crab.gd`:

```gdscript
class_name EnemyCrab
extends CharacterBody2D

@export var patrol_range: float = 80.0
@export var speed: float = 40.0

var _origin_x: float = 0.0
var _direction: int = 1

func _ready() -> void:
    _origin_x = global_position.x

func _physics_process(delta: float) -> void:
    velocity.x = _direction * speed
    move_and_slide()
    if global_position.x >= _origin_x + patrol_range:
        _direction = -1
    elif global_position.x <= _origin_x - patrol_range:
        _direction = 1

func _on_swatted() -> void:
    # 설계 5.2: 꼬리치기의 세 효과 중 넉백은 타겟이 자기 속도를 쓴다.
    # SealSwat가 타겟 속도를 쓰면 이 매 프레임 덮어써서 1프레임 만에 지워진다.
    # swat_hit(target)은 시전자를 전달하지 않으므로 player 그룹에서 찾는다.
    var player := get_tree().get_first_node_in_group("player") as Node2D
    var dir := 1.0
    if player != null:
        dir = signi(global_position.x - player.global_position.x)
    velocity.x = dir * SealSwat.KNOCKBACK
    queue_free()
```

`scripts/enemy_seagull.gd`:

```gdscript
class_name EnemySeagull
extends CharacterBody2D

@export var flight_range: float = 200.0
@export var speed: float = 90.0

var _origin_x: float = 0.0
var _direction: int = -1   # 왼쪽으로 날아온다

func _ready() -> void:
    _origin_x = global_position.x

func _physics_process(delta: float) -> void:
    velocity.x = _direction * speed
    move_and_slide()
    if global_position.x <= _origin_x - flight_range:
        _direction = 1
    elif global_position.x >= _origin_x + flight_range:
        _direction = -1

func _on_swatted() -> void:
    # 게와 동일: 넉백은 타겟이 자기 속도를 쓴다.
    var player := get_tree().get_first_node_in_group("player") as Node2D
    var dir := 1.0
    if player != null:
        dir = signi(global_position.x - player.global_position.x)
    velocity.x = dir * SealSwat.KNOCKBACK
    queue_free()
```

`scenes/entities/seal_baby.tscn`에 `Hurtbox`(Area2D + CollisionShape2D) 추가.

`scripts/seal_baby.gd`에 추가:

```gdscript
func stomp(enemy: Node) -> void:
    GameState.die()
```

그리고 `Hurtbox`의 `body_entered`를 구독해: 충돌한 몸이 `"enemy"` 그룹이고 **플레이어가 위에서 아래로 떨어지고 있을 때**(`velocity.y > 0` 이고 적의 중심이 플레이어 발보다 아래)는 `stomp()`를, 그 외의 측면·후면 충돌은 `take_hit()`를 호출한다. 단 게는 밟으면 죽으므로 위에서 밟아도 `stomp()` 경로로 간다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + level_data: 60 + generator: 55+ + enemies: 14` = `ALL 213+ CHECKS PASSED`, `exit=0`.

"게를 밟으면 사망한다"가 설계 5.3의 핵심 규칙이다. 이 검사가 실패하면 꼬리치기가 강제되지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/enemy_crab.gd scripts/enemy_seagull.gd scenes/entities/ scripts/seal_baby.gd scripts/autoload/game_state.gd tests/test_enemies.gd
git commit -m "feat: add crab and seagull enemies with stomp-death and swat-kill"
```

사용자 승인 후 실행.

---

### Task 9: 위험요소 — 얇은 얼음, 고드름, 물, 깨지는 얼음 블록

**Files:**
- Create: `scripts/hazard_thin_ice.gd`
- Create: `scripts/hazard_icicle.gd`
- Create: `scripts/hazard_water.gd`
- Create: `scripts/hazard_ice_block.gd`
- Create: `scenes/entities/hazard_thin_ice.tscn`
- Create: `scenes/entities/hazard_icicle.tscn`
- Create: `scenes/entities/hazard_water.tscn`
- Create: `scenes/entities/hazard_ice_block.tscn`
- Modify: `scripts/seal_baby.gd` (추락 사망 판정)
- Create: `tests/test_hazards.gd`

**Interfaces:**
- Consumes: Task 5의 `GameState.die()`, Task 4의 `SealSwat.swat_hit`
- Produces:
  - `ThinIce` (class_name, extends Area2D): `signal collapsed`, `@export var collapse_delay: float = 0.3`
  - `Icicle` (class_name, extends Area2D): `@export var fall_speed: float = 260.0`
  - `Water` (class_name, extends Area2D)
  - `IceBlock` (class_name, extends StaticBody2D): `func _on_swatted() -> void`
  - `BabySeal`에 추가: `const FALL_DEATH_Y := 420.0`, `func is_fallen() -> bool`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_hazards.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # 얇은 얼음: 밟으면 0.3초 후 무너짐
    GameState.reset_for_level()
    var thin := preload("res://scenes/entities/hazard_thin_ice.tscn").instantiate() as Area2D
    thin.global_position = Vector2(0, 0)
    tree.root.add_child(thin)
    await t.step_frames(tree, 2)
    var collapsed := [false]
    thin.collapsed.connect(func() -> void: collapsed[0] = true)
    # 형태 오프셋과 무관하게 겹치게 같은 좌표에 둔다.
    seal.global_position = Vector2(0, 0)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 12)
    t.check(not collapsed[0], "0.20초 후에도 아직 무너지지 않았다")
    await t.step_frames(tree, 12)
    t.check(collapsed[0], "0.30초 후 무너진다")
    t.check(thin.is_queued_for_deletion(), "무너진 얇은 얼음이 제거된다")

    # 물: 닿으면 사망
    GameState.reset_for_level()
    var water := preload("res://scenes/entities/hazard_water.tscn").instantiate() as Area2D
    water.global_position = Vector2(0, 200)
    tree.root.add_child(water)
    await t.step_frames(tree, 2)
    seal.global_position = Vector2(0, 180)
    seal.velocity = Vector2(0, 400)
    await t.step_frames(tree, 4)
    t.check(GameState.is_dead(), "물에 닿으면 사망한다")

    # 고드름: 플레이어가 지나가면 낙하한다
    GameState.reset_for_level()
    var icicle := preload("res://scenes/entities/hazard_icicle.tscn").instantiate() as Area2D
    tree.root.add_child(icicle)
    await t.step_frames(tree, 2)
    icicle.global_position = Vector2(0, -30)
    seal.global_position = Vector2(0, 0)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)
    var y0: float = icicle.global_position.y
    await t.step_frames(tree, 10)
    t.check(icicle.global_position.y > y0 + 5.0, "플레이어가 지나가면 고드름이 낙하한다")

    # 고드름에 맞으면 피격
    # respawn_at으로 무적을 해제한다. 윗 단계의 take_hit이 무적을 남겨둔다.
    seal.respawn_at(Vector2(0, 0))
    t.check(GameState.hearts == 3, "피격 전 하트 3")
    # 형태 오프셋과 무관하게 겹치게 같은 좌표에 둔다.
    icicle.global_position = seal.global_position
    await t.step_frames(tree, 6)
    t.check(GameState.hearts < 3, "고드름에 맞으면 하트가 준다")

    # 깨지는 얼음 블록: 꼬리치기로 파괴
    GameState.reset_for_level()
    var block := preload("res://scenes/entities/hazard_ice_block.tscn").instantiate() as StaticBody2D
    block.add_to_group("swat_target")
    block.global_position = Vector2(300, 0)
    tree.root.add_child(block)
    await t.step_frames(tree, 2)
    var swat := seal.get_node("SealSwat") as SealSwat
    seal.global_position = Vector2(260, 0)
    swat.try_swat()
    await t.step_frames(tree, 2)
    t.check(block.is_queued_for_deletion(), "꼬리치기로 얼음 블록이 파괴된다")

    # 레벨 아래로 추락하면 사망
    GameState.reset_for_level()
    seal.global_position = Vector2(0, BabySeal.FALL_DEATH_Y + 50)
    await t.step_frames(tree, 2)
    t.check(GameState.is_dead(), "레벨 아래로 떨어지면 사망한다")

    for n in [thin, water, icicle, block, seal]:
        if is_instance_valid(n):
            n.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `hazard_thin_ice.tscn`을 찾지 못함.

- [ ] **Step 3: 구현**

`scenes/entities/hazard_thin_ice.tscn`: 루트 `Area2D` 이름 `ThinIce`, 스크립트 `hazard_thin_ice.gd`, 자식 `CollisionShape2D` (약 64×32). 시각은 임시 `Polygon2D` (금 간 얼음).

`scripts/hazard_thin_ice.gd`:

```gdscript
class_name ThinIce
extends Area2D

signal collapsed

@export var collapse_delay: float = 0.3

var _timer: float = -1.0

func _physics_process(delta: float) -> void:
    if _timer < 0.0:
        return
    _timer -= delta
    if _timer <= 0.0:
        collapsed.emit()
        queue_free()

func _on_body_entered(body: Node) -> void:
    if body is BabySeal and _timer < 0.0:
        _timer = collapse_delay
```

`scenes/entities/hazard_water.tscn`: 루트 `Area2D` 이름 `Water`. `body_entered`에서 `GameState.die()`를 호출한다.

`scripts/hazard_icicle.gd`:

```gdscript
class_name Icicle
extends Area2D

@export var fall_speed: float = 260.0

var _falling: bool = false

func _physics_process(delta: float) -> void:
    if not _falling:
        return
    position.y += fall_speed * delta

func _on_body_entered(body: Node) -> void:
    if body is BabySeal:
        _falling = true
        # 대미지를 준다. 고드름은 맞으면 하트가 줄어든다.
        (body as BabySeal).take_hit(global_position)
```

`scenes/entities/hazard_ice_block.tscn`: 루트 `StaticBody2D` 이름 `IceBlock`, 스크립트 `hazard_ice_block.gd`, `swat_target` 그룹. 높이 90~110px 범위에서 생성기가 고른다.

`scripts/hazard_ice_block.gd`:

```gdscript
class_name IceBlock
extends StaticBody2D

func _on_swatted() -> void:
    queue_free()
```

`scripts/seal_baby.gd`에 추가: `const FALL_DEATH_Y := 420.0`. `_physics_process`에서 `global_position.y > FALL_DEATH_Y` 이면 `GameState.die()`를 호출한다. `func is_fallen() -> bool`는 그 조건을 반환한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + generator: 55+ + enemies: 14 + hazards: 9` = `ALL 222+ CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/hazard_*.gd scenes/entities/hazard_*.tscn scripts/seal_baby.gd tests/test_hazards.gd
git commit -m "feat: add thin ice, icicle, water and breakable ice block hazards"
```

사용자 승인 후 실행.

---

### Task 10: 엄마 물범, 레벨 목표, 물고기

**Files:**
- Create: `scripts/seal_mom.gd`
- Create: `scenes/entities/seal_mom.tscn`
- Create: `scripts/pickup_fish.gd`
- Create: `scenes/entities/pickup_fish.tscn`
- Create: `scripts/camera_follow.gd`
- Modify: `scenes/level/level.tscn`
- Modify: `scripts/autoload/game_state.gd`
- Create: `tests/test_goal.gd`

**Interfaces:**
- Consumes: Task 7의 `LevelGenerator.generate` 반환 딕셔너리, Task 5의 `GameState`
- Produces:
  - `MomSeal` (class_name, extends Node2D): `func celebrate() -> void`, 피벗 `BodyPivot`/`HeadPivot`/`FlipperPivot`
  - `Fish` (class_name, extends Area2D): `signal collected`
  - `CameraFollow` (class_name, extends Node2D): `@export var target_path: NodePath`, `func _physics_process(delta: float) -> void`
  - `Level` (씬 루트, `scripts/level.gd`): `func setup(data: LevelData) -> BabySeal` — 생성 결과를 조립하고 물범을 배치해 반환
  - `GameState`에 추가: `signal level_completed(level_index: int)`, `func complete_level() -> void`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_goal.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var level_scene := preload("res://scenes/level/level.tscn").instantiate() as Node
    tree.root.add_child(level_scene)
    await t.step_frames(tree, 2)

    var data := LevelRegistry.get_level(1) as LevelData
    var seal := (level_scene as Node).call("setup", data) as BabySeal
    t.check(seal != null, "setup이 물범을 반환한다")

    var spawn: Vector2 = seal.global_position
    t.check(spawn.x < 600.0, "물범이 앞부분에 스폰된다")

    # 목표(엄마) 배치
    var mom := level_scene.find_child("MomSeal", true, false) as MomSeal
    t.check(mom != null, "엄마 물범이 레벨에 있다")
    t.check(mom != null and mom.global_position.x > data.length_px * 0.9,
        "엄마가 레벨 길이의 90%% 이후에 있다")

    # 도착 판정
    var done := [false]
    GameState.level_completed.connect(func(_i: int) -> void: done[0] = true)
    seal.global_position = mom.global_position
    await t.step_frames(tree, 3)
    t.check(done[0], "엄마에게 도착하면 레벨이 클리어된다")

    # 물고기
    GameState.reset_for_level()
    GameState.fish_total = 3
    var fish := preload("res://scenes/entities/pickup_fish.tscn").instantiate() as Area2D
    fish.global_position = Vector2(100, 0)
    tree.root.add_child(fish)
    await t.step_frames(tree, 2)
    t.check(GameState.fish_collected == 0, "물고기 수집 전 0")
    seal.global_position = Vector2(100, 0)
    await t.step_frames(tree, 3)
    t.check(GameState.fish_collected == 1, "물고기를 먹으면 1 증가")
    t.check(fish.is_queued_for_deletion(), "먹은 물고기가 제거된다")

    # 엄마의 celebrate
    var flipper := mom.get_node("FlipperPivot") as Node2D
    var rot_before: float = flipper.rotation
    mom.celebrate()
    await t.step_frames(tree, 30)
    t.check(absf(flipper.rotation - rot_before) > 0.001, "celebrate 시 지느러미가 움직인다")

    for n in [level_scene, fish]:
        if is_instance_valid(n):
            n.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `seal_mom.tscn`을 찾지 못함.

- [ ] **Step 3: 구현**

`scenes/entities/seal_mom.tscn`: 루트 `Node2D` 이름 `MomSeal`, 스크립트 `seal_mom.gd`. `BodyPivot`, `HeadPivot`, `FlipperPivot` 세 `Node2D`와 각각의 `VisualSlot` → `PolygonPuppet` → `Polygon2D`. `AnimationPlayer`에 `idle`, `wave` 2개. 트랙은 피벗 프로퍼티만 겨냥한다.

`scripts/seal_mom.gd`:

```gdscript
class_name MomSeal
extends Node2D

@onready var _anim: AnimationPlayer = $AnimationPlayer

func celebrate() -> void:
    _anim.play("wave")
```

`scenes/entities/pickup_fish.tscn`: 루트 `Area2D` 이름 `Fish`, 스크립트 `pickup_fish.gd`, `"fish"` 그룹, `CollisionShape2D` (약 24×20)과 임시 `Polygon2D`.

`scripts/pickup_fish.gd`:

```gdscript
class_name Fish
extends Area2D

signal collected

func _on_body_entered(body: Node) -> void:
    if body is BabySeal:
        collected.emit()
        queue_free()
```

`scripts/camera_follow.gd`:

```gdscript
class_name CameraFollow
extends Node2D

@export var target_path: NodePath

func _physics_process(delta: float) -> void:
    var target := get_node_or_null(target_path) as Node2D
    if target == null:
        return
    global_position.x = target.global_position.x
```

수직은 데드존 없이 따라가지 않는다(설계 8.3: 수평 추적 + 수직 데드존. 데드존은 빌더 재량).

`scenes/level/level.tscn`을 조립한다: 루트 `Node2D` 이름 `Level`, 스크립트 `scripts/level.gd`. 자식으로 `Camera2D`(스크립트 `camera_follow.gd`)와 물범이 들어갈 자리. `setup(data)`:

1. `LevelGenerator.new().generate(data)`를 호출한다.
2. 반환된 `root`를 자식으로 붙인다.
3. `spawn` 위치에 `seal_baby.tscn`을 인스턴스화해 붙이고 반환한다.
4. 카메라의 `target_path`를 물범 경로로 설정한다.
5. 물범이 엄마(`"goal"` 그룹)에 닿으면 `GameState.complete_level()`을 호출한다. 판정은 물범의 `x` 좌표가 `goal_x` 이상이 되는 것으로 단순하게 한다.

`scripts/autoload/game_state.gd`에 추가:

```gdscript
signal level_completed(level_index: int)

func complete_level() -> void:
    level_completed.emit(current_level_index)
```

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + enemies: 14 + hazards: 9 + goal: 9` = `ALL 231+ CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scripts/seal_mom.gd scenes/entities/seal_mom.tscn scripts/pickup_fish.gd scenes/entities/pickup_fish.tscn scripts/camera_follow.gd scenes/level/level.tscn scripts/level.gd scripts/autoload/game_state.gd tests/test_goal.gd
git commit -m "feat: add mother seal goal, fish pickups and level assembly"
```

사용자 승인 후 실행.

---

### Task 11: HUD

**Files:**
- Create: `scenes/ui/hud.tscn`
- Create: `scripts/hud.gd`
- Modify: `scenes/level/level.tscn`
- Create: `tests/test_hud.gd`

**Interfaces:**
- Consumes: Task 5의 `GameState.hearts_changed`
- Produces: `Hud` (class_name, extends CanvasLayer): `func set_hearts(value: int) -> void`, `func set_level(index: int) -> void`, `func set_fish(collected: int, total: int) -> void`, `func get_heart_count() -> int`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_hud.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var hud := preload("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
    tree.root.add_child(hud)
    await t.step_frames(tree, 2)

    t.check(hud.get_heart_count() == 3, "초기 하트 3개")

    hud.set_level(2)
    hud.set_fish(3, 7)
    GameState.hearts_changed.emit(1)
    await t.step_frames(tree, 2)
    t.check(hud.get_heart_count() == 1, "hearts_changed 시 하트가 1로 줄어든다")

    GameState.hearts_changed.emit(3)
    await t.step_frames(tree, 2)
    t.check(hud.get_heart_count() == 3, "hearts_changed 시 하트가 3으로 회복된다")

    hud.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `hud.tscn`을 찾지 못함.

- [ ] **Step 3: 구현**

`scripts/hud.gd`:

```gdscript
class_name Hud
extends CanvasLayer

@onready var _heart_box: HBoxContainer = $HeartBox

func _ready() -> void:
    GameState.hearts_changed.connect(set_hearts)
    set_hearts(GameState.hearts)

func set_hearts(value: int) -> void: ...
func set_level(index: int) -> void: ...
func set_fish(collected: int, total: int) -> void: ...
func get_heart_count() -> int: ...
```

하트는 `heart.png` 자리 대신 임시 `ColorRect` 또는 `Polygon2D` 도형을 `value` 개수만큼 `_heart_box`에 넣는다. Task 14에서 PNG로 교체한다. `set_level`은 `Label`에 "LEVEL N", `set_fish`는 `Label`에 "물고기 N / M"을 쓴다.

`scenes/level/level.tscn`에 `hud.tscn`을 자식으로 추가한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + hazards: 9 + goal: 9 + hud: 3` = `ALL 234+ CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scenes/ui/hud.tscn scripts/hud.gd scenes/level/level.tscn tests/test_hud.gd
git commit -m "feat: add HUD with hearts, level number and fish counter"
```

사용자 승인 후 실행.

---

### Task 12: UI 흐름과 레벨 전환

**Files:**
- Create: `scenes/main.tscn`
- Create: `scripts/main.gd`
- Create: `scenes/ui/title.tscn`
- Create: `scenes/ui/level_complete.tscn`
- Create: `scenes/ui/game_over.tscn`
- Create: `scripts/ui_screens.gd`
- Modify: `project.godot` (메인 씬 지정)
- Create: `tests/test_flow.gd`

**Interfaces:**
- Consumes: Task 5의 `GameState`, Task 10의 `Level.setup`
- Produces:
  - `Main` (class_name, extends Node): `func start_game() -> void`, `func goto_level(index: int) -> void`, `func show_level_complete() -> void`, `func show_game_over() -> void`, `func retry_level() -> void`
  - `UiScreens` (class_name, extends RefCounted): `func show_title() -> void`, `func show_level_complete() -> void`, `func show_game_over() -> void`, `func hide_all() -> void` — `scenes/ui/*.tscn`을 인스턴스화해 `Main` 아래에 붙인다

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_flow.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var main := preload("res://scenes/main.tscn").instantiate() as Node
    tree.root.add_child(main)
    await t.step_frames(tree, 2)

    GameState.current_level_index = 1
    main.call("goto_level", 1)
    await t.step_frames(tree, 3)
    var level := main.find_child("Level", true, false) as Node
    t.check(level != null, "레벨 1이 로드된다")
    var seal := main.find_child("BabySeal", true, false) as BabySeal
    t.check(seal != null, "물범이 레벨에 있다")

    # 레벨 1 클리어 → 레벨 2
    GameState.complete_level()
    await t.step_frames(tree, 3)
    t.check(GameState.current_level_index == 2, "레벨 1 클리어 시 레벨 2로 간다")

    # 마지막 레벨 클리어
    GameState.current_level_index = LevelRegistry.level_count()
    GameState.complete_level()
    await t.step_frames(tree, 3)
    var complete_screen := main.find_child("LevelComplete", true, false)
    t.check(complete_screen != null, "마지막 레벨 클리어 시 완료 화면이 뜬다")

    # 사망 → 게임오버
    main.call("goto_level", 2)
    await t.step_frames(tree, 3)
    GameState.reset_for_level()
    GameState.die()
    await t.step_frames(tree, 3)
    var over_screen := main.find_child("GameOver", true, false)
    t.check(over_screen != null, "사망 시 게임오버 화면이 뜬다")

    # 재시도
    main.call("retry_level")
    await t.step_frames(tree, 3)
    t.check(GameState.hearts == GameState.MAX_HEARTS, "재시도 시 하트가 복원된다")

    main.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `main.tscn`을 찾지 못함.

- [ ] **Step 3: 구현**

`scripts/main.gd`:

```gdscript
class_name Main
extends Node

func start_game() -> void:
    GameState.current_level_index = 1
    goto_level(1)

func goto_level(index: int) -> void:
    GameState.current_level_index = index
    GameState.reset_for_level()
    var old := find_child("Level", true, false)
    if old != null:
        old.queue_free()
    var level := preload("res://scenes/level/level.tscn").instantiate() as Node
    level.name = "Level"
    add_child(level)
    var data := LevelRegistry.get_level(index) as LevelData
    var seal = level.call("setup", data)
    # HUD 배선은 setup() 반환 이후에 한다. fish_total은 level.setup() 안에서
    # 설정되므로, _ready()에서 시드하면 fish_total=0을 읽는다.
    var hud := find_child("Hud", true, false) as Hud
    if hud != null:
        hud.set_level(index)
        hud.set_fish(GameState.fish_collected, GameState.fish_total)
    return seal

func show_level_complete() -> void: ...
func show_game_over() -> void: ...
func retry_level() -> void:
    goto_level(GameState.current_level_index)
```

**HUD 배선 (Task 11 리뷰에서 확인된 계획 공백).** `set_level`/`set_fish`를 위처럼 `level.setup()` 반환 이후에 호출한다. 또한 물고기 카운터가 갱신되도록 `GameState`에 `fish_changed` 시그널을 추가하고 `collect_fish()`에서 발신하며, `Fish.collected` 시그널을 구독해 `GameState.collect_fish()`와 `hud.set_fish()`를 함께 부른다.

**한국어 폰트 (Task 11 리뷰에서 확인된 계획 공백).** 이 태스크가 처음으로 한국어 UI(제목·다음 레벨·재시도 버튼)를 도입한다. `/System/Library/Fonts/Supplemental/AppleGothic.ttf`를 `assets/fonts/korean.ttf`로 복사해 `FontFile` 리소스로 등록하고, `Theme`의 `default_font`로 지정한 뒤 `project.godot`의 `gui/theme/custom`에 연결한다. 이렇게 하면 물고기 레이블(`hud.tscn`)과 새 버튼의 한국어가 두부(tofu)로 렌더링되지 않는다.

`_ready`에서 연결한다: `GameState.level_completed` → 인덱스가 `LevelRegistry.level_count()`면 `show_level_complete()`, 아니면 `goto_level(current_level_index + 1)`. `GameState.player_died` → `show_game_over()`.

`scripts/ui_screens.gd`: `UiScreens`는 세 화면 씬을 인스턴스화해 `Main`에 붙이고 이전 화면은 `queue_free()`한다. 각 화면에는 버튼 하나(시작 / 다음 레벨 / 재시도)를 두고 `pressed`를 해당 함수에 연결한다.

`scenes/main.tscn`: 루트 `Node` 이름 `Main`, 스크립트 `main.gd`.

`project.godot`의 `run/main_scene`을 `res://scenes/main.tscn`으로 지정한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + goal: 9 + hud: 3 + flow: 6` = `ALL 240+ CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add scenes/main.tscn scripts/main.gd scenes/ui/ scripts/ui_screens.gd project.godot tests/test_flow.gd
git commit -m "feat: add title, level complete and game over flow with level transitions"
```

사용자 승인 후 실행.

---

### Task 13: 밀려오는 빙산 (레벨 5)

**Files:**
- Create: `scripts/iceberg.gd`
- Create: `scenes/entities/iceberg.tscn`
- Modify: `scripts/level_generator.gd`
- Modify: `scripts/seal_baby.gd`
- Create: `tests/test_iceberg.gd`

**Interfaces:**
- Consumes: Task 5의 `GameState`, Task 7의 `LevelGenerator`, Task 12의 `Main`
- Produces: `Iceberg` (class_name, extends Area2D): `@export var speed: float = 40.0`, `func reposition_behind(x: float) -> void`, `func is_soft_wall() -> bool`
- `BabySeal`에 추가: `signal respawned` — 부활 직후에 발생. `Main`이 구독해 빙산을 재배치한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_iceberg.gd`:

```gdscript
extends RefCounted

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # 시간 압박이 없는 레벨에는 빙산이 없다
    var gen := LevelGenerator.new()
    var r1: Dictionary = gen.generate(LevelRegistry.get_level(1) as LevelData)
    var l1 := r1["root"] as Node2D
    t.check(l1.find_child("Iceberg", true, false) == null, "레벨 1에 빙산이 없다")
    l1.free()

    # 레벨 5에는 빙산이 있다
    var r5: Dictionary = gen.generate(LevelRegistry.get_level(5) as LevelData)
    var l5 := r5["root"] as Node2D
    var berg := l5.find_child("Iceberg", true, false) as Iceberg
    t.check(berg != null, "레벨 5에 빙산이 있다")
    if berg == null:
        return

    tree.root.add_child(l5)
    await t.step_frames(tree, 2)
    t.check(berg.is_soft_wall(), "빙산은 소프트 월이다 (즉사 아님)")

    var x0: float = berg.global_position.x
    await t.step_frames(tree, 30)
    t.check(berg.global_position.x > x0, "빙산이 오른쪽으로 이동한다")

    # 접촉 시 하트 1 감소, 즉사 아님
    GameState.reset_for_level()
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)
    seal.global_position = berg.global_position + Vector2(0, -20)
    await t.step_frames(tree, 3)
    t.check(GameState.hearts == 2, "빙산 접촉 시 하트가 1 준다")
    t.check(not GameState.is_dead(), "빙산 접촉으로 즉사하지 않는다")

    # 부활 시 빙산이 플레이어 뒤로 재배치된다
    GameState.reset_for_level()
    var respawn_at := Vector2(2000, 100)
    seal.respawn_at(respawn_at)
    berg.reposition_behind(respawn_at.x)
    t.check(berg.global_position.x < respawn_at.x - 200.0,
        "부활 시 빙산이 플레이어 뒤 200px 이상에 있다")
    await t.step_frames(tree, 5)
    t.check(not GameState.is_dead(), "부활 직후 빙산이 플레이어를 덮치지 않는다")

    # 연속 접촉이 무한 루프를 만들지 않는다
    GameState.reset_for_level()
    for i in 5:
        seal.global_position = berg.global_position + Vector2(0, -20)
        await t.step_frames(tree, 3)
    t.check(GameState.hearts >= 0, "연속 접촉 후에도 하트가 0 미만이 아니다")
    t.check(GameState.hearts > 0 or GameState.is_dead(), "빙산 때문에 영원히 죽지 않는 상태가 아니다")

    seal.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `Iceberg` 클래스를 찾지 못함.

- [ ] **Step 3: 구현**

`scenes/entities/iceberg.tscn`: 루트 `Area2D` 이름 `Iceberg`, 스크립트 `iceberg.gd`, `CollisionShape2D`. 시각은 임시 `Polygon2D` (커다란 빙산).

`scripts/iceberg.gd`:

```gdscript
class_name Iceberg
extends Area2D

@export var speed: float = 40.0

var _start_x: float = 0.0

func _ready() -> void:
    _start_x = global_position.x

func is_soft_wall() -> bool:
    return true

func reposition_behind(x: float) -> void:
    global_position.x = x - 400.0

func _physics_process(delta: float) -> void:
    global_position.x += speed * delta

func _on_body_entered(body: Node) -> void:
    if body is BabySeal:
        var seal := body as BabySeal
        if seal.is_invulnerable:
            return
        # 소프트 월: 즉사가 아니라 넉백만
        seal.velocity.x = -180.0
        GameState.lose_heart()
```

`scripts/level_generator.gd` 수정: `data.has_time_pressure`가 `true`일 때만 레벨 시작점 뒤쪽에 `Iceberg`를 하나 추가한다. `speed`는 40.0.

`scripts/seal_baby.gd` 수정: `respawn_at()` 끝에서 `respawned` 시그널을 발생시킨다.

`scripts/main.gd` 수정: 레벨을 조립한 뒤 물범의 `respawned` 시그널을 구독해, 레벨에 `Iceberg`가 있으면 `reposition_behind(seal.global_position.x)`를 호출한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: `… + hud: 3 + flow: 6 + iceberg: 10` = `ALL 250+ CHECKS PASSED`, `exit=0`.

"부활 직후 빙산이 플레이어를 덮치지 않는다"가 Review Focus 2번이다. 이 검사가 없으면 체크포인트에서 되살아난 직후 빙산이 덮쳐서 죽음이 무한 반복하는 막힘이 생긴다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/iceberg.gd scenes/entities/iceberg.tscn scripts/level_generator.gd scripts/seal_baby.gd scripts/main.gd tests/test_iceberg.gd
git commit -m "feat: add level 5 soft-wall iceberg that repositions behind respawns"
```

사용자 승인 후 실행.

---

### Task 14: 스프라이트 교체 검증과 후처리 자동화

**Files:**
- Create: `tools/prepare_sprites.sh`
- Create: `tests/test_swap.gd`
- Modify: `docs/` (아래 Step 3 참고)

**Interfaces:**
- Consumes: Task 3의 피벗·시각 슬롯 구조
- Produces: `tools/prepare_sprites.sh` — `raw/` 의 PNG를 배경 제거·축소해 `assets/sprites/` 에 배치

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_swap.gd`:

```gdscript
extends RefCounted

const PIVOTS := ["BodyPivot", "HeadPivot", "TailPivot", "FlipperFrontPivot", "FlipperBackPivot"]

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # 1. 게임 스크립트가 시각 노드 이름을 참조하지 않는다
    var forbidden := ["PolygonPuppet", "VisualSlot/", "Polygon2D"]
    var offenders: Array[String] = []
    var dir := DirAccess.open("res://scripts")
    for file in dir.get_files(true):
        if not file.ends_with(".gd"):
            continue
        var text := FileAccess.get_file_as_string("res://scripts/" + file)
        for f in forbidden:
            if f in text:
                offenders.append("%s 참조 %s" % [file, f])
    t.check(offenders.is_empty(), "게임 스크립트가 시각 노드를 참조하지 않는다: %s" % str(offenders))

    # 2. 더미 스프라이트로 교체한 물범이 게임 로직을 유지한다
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    var tex := ImageTexture.create_from_image(img)

    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    for p in PIVOTS:
        var pivot := seal.get_node_or_null(p) as Node2D
        if pivot == null:
            continue
        var slot := pivot.get_node_or_null("VisualSlot") as Node2D
        if slot == null:
            continue
        var puppet := slot.get_node_or_null("PolygonPuppet") as Node2D
        if puppet != null:
            puppet.queue_free()
        var sprite := Sprite2D.new()
        sprite.texture = tex
        slot.add_child(sprite)

    await t.step_frames(tree, 2)

    # 이동이 그대로 동작한다
    seal.set_test_floor(true)
    seal.velocity = Vector2.ZERO
    Input.action_press("move_right")
    await t.step_frames(tree, 30)
    t.check(seal.get_horizontal_speed() > 50.0, "스프라이트 교체 후에도 이동이 동작한다")
    Input.action_release("move_right")

    # 꼬리치기가 그대로 동작한다
    var swat := seal.get_node_or_null("SealSwat") as SealSwat
    t.check(swat != null, "스프라이트 교체 후에도 SealSwat이 있다")
    t.check(swat.try_swat(), "스프라이트 교체 후에도 꼬리치기가 통한다")

    # 애니메이션이 그대로 동작한다
    var anim := seal.get_node_or_null("SealAnim") as SealAnim
    anim.play("run")
    t.check(anim.current() == "run", "스프라이트 교체 후에도 애니메이션이 재생된다")
    var body := seal.get_node("BodyPivot") as Node2D
    var s0: Vector2 = body.scale
    await t.step_frames(tree, 20)
    t.check(body.scale != s0, "스프라이트 교체 후에도 피벗이 애니메이션으로 변한다")

    seal.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: 실패할 수 있다. 이 테스트는 앞선 태스크에서 구조가 올바르면 이미 통과한다. 실패한다면 이전 태스크의 구조를 고친다.

- [ ] **Step 3: 후처리 스크립트 구현**

`tools/prepare_sprites.sh`: `raw/` 에서 PNG를 읽어 마젠타 배경을 제거하고 균일 축소해 `assets/sprites/` 에 배치한다. 규칙은 `png-prompts.md` 11장과 같다:

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets/sprites/seal assets/sprites/mom assets/sprites/enemies \
         assets/sprites/hazards assets/sprites/env assets/sprites/ui

process() {  # process <입력> <출력> <캔버스규격>
    local in="$1" out="$2" size="$3"
    ffmpeg -y -loglevel error -i "$in" \
        -vf "chromakey=0xFF00FF:0.22:0.04,scale=${size}:${size}:flags=lanczos,format=rgba" \
        "$out"
}

# 128 캔버스 파츠 → 64
for f in baby_tail baby_body baby_belly baby_flipper_back baby_flipper_front \
         baby_head baby_face baby_whiskers; do
    process "raw/${f}.png" "assets/sprites/seal/${f}.png" 64
done
# ... 이하 png-prompts.md 4장의 표와 파일명 규칙에 따라 전 부위를 같은 패턴으로
```

스크립트가 끝나면 존재하는 파일 목록과 규격을 출력한다. 규격 파일이 하나도 없으면 경고만 하고 종료 코드는 0으로 둔다(그림은 아직 도착하지 않았을 수 있다).

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
bash -n tools/prepare_sprites.sh && echo "문법 OK"
```

Expected: `… + flow: 6 + iceberg: 10 + swap: 6` = `ALL 256+ CHECKS PASSED`, `exit=0`.

- [ ] **Step 5: 커밋**

```bash
git add tools/prepare_sprites.sh tests/test_swap.gd
git commit -m "test: prove game logic survives polygon-to-sprite visual swap"
```

사용자 승인 후 실행.

---

### Task 15: 사운드 5종

**Files:**
- Create: `scripts/sound_player.gd`
- Create: `tools/make_sfx.sh`
- Create: `tests/test_sound.gd`
- Modify: `scripts/seal_baby.gd` (점프·피격)
- Modify: `scripts/seal_swat.gd` (꼬리치기)
- Modify: `scripts/enemy_crab.gd`, `scripts/enemy_seagull.gd` (적 제거)
- Modify: `scripts/main.gd` (엄마 도착)
- Modify: `project.godot` (`SoundPlayer` Autoload 등록)

**Interfaces:**
- Consumes: Task 5의 `GameState`, Task 10의 레벨 클리어
- Produces:
  - `SoundPlayer` (class_name, extends Node, Autoload): `func play(name: String) -> void`, `func has(name: String) -> bool`, `signal sfx_played(name: String)`
  - SFX 이름 (정확히 이 문자열): `jump`, `swat`, `enemy_down`, `hurt`, `arrive`
  - 파일 규칙: `assets/sfx/<name>.wav`

- [ ] **Step 1: 실패하는 테스트 작성**

`tests/test_sound.gd`:

```gdscript
extends RefCounted

const NAMES := ["jump", "swat", "enemy_down", "hurt", "arrive"]

func run(t: TestHelper) -> void:
    for n in NAMES:
        t.check(SoundPlayer.has(n), "SFX %s가 등록돼 있다" % n)

    # play가 크래시 없이 동작하고 시그널을 낸다
    var played: Array[String] = []
    SoundPlayer.sfx_played.connect(func(n: String) -> void: played.append(n))
    for n in NAMES:
        SoundPlayer.play(n)
    t.check(played.size() == NAMES.size(), "5개 SFX가 모두 재생 신호를 낸다")

    # 각 이벤트가 올바른 사운드를 낸다
    played.clear()
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    var tree := Engine.get_main_loop() as SceneTree
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    seal.set_test_floor(true)
    Input.action_press("jump")
    await t.step_frames(tree, 2)
    Input.action_release("jump")
    t.check(played.has("jump"), "점프 시 jump 사운드가 난다")

    (seal.get_node("SealSwat") as SealSwat).try_swat()
    t.check(played.has("swat"), "꼬리치기 시 swat 사운드가 난다")

    seal.take_hit(Vector2(100, 0))
    t.check(played.has("hurt"), "피격 시 hurt 사운드가 난다")

    var crab := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as Node
    tree.root.add_child(crab)
    crab.call("_on_swatted")
    t.check(played.has("enemy_down"), "적 제거 시 enemy_down 사운드가 난다")

    GameState.complete_level()
    t.check(played.has("arrive"), "도착 시 arrive 사운드가 난다")

    seal.queue_free()
    crab.queue_free()
```

- [ ] **Step 2: 실패하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
```

Expected: FAIL — `SoundPlayer` Autoload가 없음.

- [ ] **Step 3: 구현**

`scripts/sound_player.gd`:

```gdscript
class_name SoundPlayer
extends Node

signal sfx_played(name: String)

const DIR := "res://assets/sfx/"
const NAMES := ["jump", "swat", "enemy_down", "hurt", "arrive"]

var _streams: Dictionary = {}

func _ready() -> void:
    for n in NAMES:
        var path := DIR + n + ".wav"
        if ResourceLoader.exists(path):
            _streams[n] = load(path)

func has(name: String) -> bool:
    return _streams.has(name)

func play(name: String) -> void:
    if not _streams.has(name):
        return
    var player := AudioStreamPlayer.new()
    add_child(player)
    player.stream = _streams[name]
    player.finished.connect(player.queue_free)
    player.play()
    sfx_played.emit(name)
```

재생은 매번 `AudioStreamPlayer`를 만들어 한 번 쓰고 버린다. 같은 사운드가 겹쳐도 끊기지 않는다. 파일이 없으면 `play()`는 조용히 리턴하므로 사운드가 없어도 게임은 동작한다.

`tools/make_sfx.sh` — 5개 WAV을 합성한다. 외부 에셋이 필요 없다:

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p assets/sfx
tone() {  # tone <출력> <주파수> <길이>
    ffmpeg -y -loglevel error -f lavfi -i "sine=frequency=$2:duration=$3" \
        -af "afade=t=in:st=0:d=0.01,afade=t=out:st=$(python3 -c "print(max(0.01,$3-0.03))"):d=0.02,volume=0.5" \
        "assets/sfx/$1.wav"
}
tone jump        520 0.12
tone swat        300 0.15
tone enemy_down  700 0.10
tone hurt        180 0.20
ffmpeg -y -loglevel error \
    -f lavfi -i "sine=frequency=523:duration=0.15" \
    -f lavfi -i "sine=frequency=659:duration=0.15" \
    -f lavfi -i "sine=frequency=784:duration=0.15" \
    -f lavfi -i "sine=frequency=1046:duration=0.15" \
    -filter_complex "[0][1][2][3]concat=n=4:v=0:a=1,volume=0.5" \
    assets/sfx/arrive.wav
```

발생 지점: `seal_baby.gd`의 점프와 `take_hit`, `seal_swat.gd`의 `try_swat()` 성공 시, `enemy_crab.gd`/`enemy_seagull.gd`의 `_on_swatted()`, `main.gd`의 `level_completed` 처리에서 각각 `SoundPlayer.play()`를 호출한다.

- [ ] **Step 4: 통과하는지 확인**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_runner.tscn; echo "exit=$?"
bash tools/make_sfx.sh && ls -1 assets/sfx/
```

Expected: `… + iceberg: 10 + swap: 6 + sound: 7` = `ALL 263+ CHECKS PASSED`, `exit=0`.

headless에는 오디오 장치가 없어 실제 소리가 나지 않는다. 이 테스트는 "사운드가 올바른 이벤트에서 올바른 이름으로 재생되는지"만 확인하며, 소리 자체는 수동 검증에서 듣는다.

- [ ] **Step 5: 커밋**

```bash
git add scripts/sound_player.gd tools/make_sfx.sh tests/test_sound.gd scripts/seal_baby.gd scripts/seal_swat.gd scripts/enemy_crab.gd scripts/enemy_seagull.gd scripts/main.gd project.godot
git commit -m "feat: add five synthesized sound effects wired to game events"
```

사용자 승인 후 실행.

---

## 완료 기준

전 태스크가 끝나면 다음이 모두 참이어야 한다:

1. `godot --headless --path . res://tests/test_runner.tscn` 이 `exit=0`.
2. 레벨 1은 점프만으로, 레벨 2는 꼬리치기로만 클리어 가능.
3. 레벨 5의 빙산은 압박이지 벽이 아님.
4. `PolygonPuppet`을 스프라이트로 교체해도 스크립트와 애니메이션 파일을 한 줄도 고치지 않음 (Task 14 검증).
5. 5종 사운드가 설계 11장의 이벤트에서 재생된다 (Task 15 검증).


