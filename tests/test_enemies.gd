extends RefCounted

# 작업 8: 적 — 게와 갈매기.
#
# 설계 5.3의 핵심 규칙: 게는 밟으면 죽고, 꼬리치기로만 제거된다. 갈매기는
# 점프로 회피하거나 꼬리치기로 제거한다.
# 설계 5.2의 꼬리치기 효과 중 넉백(KNOCKBACK 220)은 대상이 자기 속도로 적용한다.
#
# 밟기 vs 측면 판정은 물범의 "이번 프레임 이동 직전" 수직 속도로 한다. Area2D의
# body_entered는 move_and_slide() 이후에 발사되고, 그 시점의 velocity.y는 착지로
# 이미 0이 되어 있다(탐측 확인). 그래서 _physics_process에서 이동 직전 값을
# 따로 보관한다(BabySeal._descending_velocity).

# 꼬리치기 판정은 Area2D가 물리 서버에 등록된 뒤 한 프레임 뒤에 나온다.
# 시동 후 2프레임 양보한다: 1프레임은 판정 영역 등록, 1프레임은 queue_free()
# 로 인한 실제 제거(trailing 시그널)를 기다리기 때문이다.
const SWAT_SETTLE_FRAMES := 2

# 꼬리치기 판정이 완전히 끝날 때까지. SWAT_DURATION 0.15초(9프레임) + 여유.
# 판정이 살아 있는 채로 적 옆에 물범을 두면, 의도하지 않은 꼬리치기가 적을
# queue_free()해 버려서 뒤쪽 검사가 엉뚱한 상태를 보게 된다.
const SWAT_EXPIRE_FRAMES := 12

# 꼬리치기 쿨다운 0.40초(24프레임) + 여유 1프레임.
const SWAT_COOLDOWN_FRAMES := 25

# 게 순찰: 원점 기준 ±80px를 40px/s로 이동한다. 2초(120프레임)면 한 방향으로
# 80px, 왕복으로 -80px까지 갔다가 돌아오므로 범위 이내다.
const CRAB_PATROL_FRAMES := 120

# 갈매기 비행: 원점 기준 ±200px를 90px/s로 이동한다. 갈매기는 왼쪽으로
# 날아오므로, 200프레임(3.33초)이면 -200px까지 갔다가 +방향으로 전환된다.
const GULL_FLIGHT_FRAMES := 200

# 물범이 게 원점보다 위에 있어야 "밟기"로 읽힌다. 물범 몸체는 32px(반 16)이고
# 게 몸체는 24px(반 12)이므로, -32는 물범 중심이 게 중심보다 32px 위다.
const STOMP_DROP := -32.0

# 측면 접촉: 물범 원점이 게 원점보다 아래(또는 같은 높이)에 있어야 한다.
const SIDE_OFFSET_Y := 12.0

# 꼬리치기 사거리는 REACH 44(판정 영역 중심이 전방 22px)이고 물범 몸체 폭은
# 48(반 24)이다. 몸체가 겹치면 물리 서버가 밀어내서 판정이 사라지므로, 몸체는
# 겹치지 않으면서 판정 영역만 적에 닿는 거리를 둔다.
const SWAT_STANDOFF := 50.0


# 꼬리치기 맞은 적은 queue_free()로 제거된다. 해제된 노드의 프로퍼티를 읽거나
# TypedArray에 넣으면 런타임 오류로 검사가 통째로 중단되므로(탐측 확인), 명중
# 기록은 노드가 아니라 이름(String)으로 남기고, 넉백 속도는 제거 직전 시그널에서
# 복사해 둔다.
func _watch_knockback(node: Node) -> Array[float]:
    var seen: Array[float] = []
    node.tree_exiting.connect(func() -> void: seen.append((node as CharacterBody2D).velocity.x))
    return seen

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # ── 게 순찰 (설계 5.3) ──
    var crab := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D
    crab.global_position = Vector2(0, 0)
    await t.step_frames(tree, 1)
    tree.root.add_child(crab)
    await t.step_frames(tree, 2)
    var x0: float = crab.global_position.x
    await t.step_frames(tree, CRAB_PATROL_FRAMES)
    t.check(absf(crab.global_position.x - x0) > 10.0, "게가 이동한다")
    t.check(absf(crab.global_position.x - x0) <= crab.patrol_range + 1.0,
        "게가 순찰 범위를 벗어나지 않는다")

    # ── 갈매기 비행 (설계 5.3) ──
    var gull := preload("res://scenes/entities/enemy_seagull.tscn").instantiate() as CharacterBody2D
    gull.global_position = Vector2(500, -100)
    await t.step_frames(tree, 1)
    tree.root.add_child(gull)
    await t.step_frames(tree, 2)
    var g0: float = gull.global_position.x
    await t.step_frames(tree, GULL_FLIGHT_FRAMES)
    t.check(absf(gull.global_position.x - g0) > 10.0, "갈매기가 비행한다")
    t.check(absf(gull.global_position.x - g0) <= gull.flight_range + 1.0,
        "갈매기가 비행 범위를 벗어나지 않는다")

    # ── 물범 준비 ──
    GameState.reset_for_level()
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # ── 게를 밟으면 사망 (설계 5.3 핵심 규칙) ──
    # 물범을 게 원점보다 위에 두고 떨어뜨린다. y+는 아래이므로 낙하는 양의
    # velocity.y. 판정은 이동 직전 속도를 쓰므로 물범은 내려오는 중이다.
    seal.global_position = crab.global_position + Vector2(0, STOMP_DROP)
    seal.velocity = Vector2(0, 300.0)
    await t.step_frames(tree, 3)
    t.check(GameState.is_dead(), "게를 밟으면 사망한다")

    # ── 꼬리치기로 제거 + 넉백 (설계 5.2) ──
    GameState.reset_for_level()
    var swatted: Array[String] = []
    var swat := seal.get_node("SealSwat") as SealSwat
    swat.swat_hit.connect(func(target: Node) -> void: swatted.append(target.name))

    var crab_knock := _watch_knockback(crab)
    # 물범은 게보다 오른쪽에 서서 왼쪽을 향해 친다. 게는 물범의 왼쪽에 있으므로
    # 넉백은 음수 방향 (설계 5.2, KNOCKBACK 220).
    seal.global_position = crab.global_position + Vector2(SWAT_STANDOFF, 0)
    seal.facing = -1
    seal.velocity = Vector2.ZERO
    seal.try_swat()
    t.check(swat.is_active(), "게에 꼬리치기가 시동된다")
    await t.step_frames(tree, SWAT_SETTLE_FRAMES)
    t.check(swatted.has("EnemyCrab"), "게에 꼬리치기가 적중한다")
    t.check(crab_knock.size() > 0, "꼬리치기 맞은 게가 제거된다")
    t.check(crab_knock[0] < 0.0, "게가 물범 반대편으로 넉백된다")
    t.approx(crab_knock[0], -SealSwat.KNOCKBACK, 1.0, "게 넉백 속도 220")

    # 갈매기도 같은 규칙. 쿨다운(0.40초)을 먼저 만료시킨다.
    await t.step_frames(tree, SWAT_COOLDOWN_FRAMES)
    var gull_knock := _watch_knockback(gull)
    seal.global_position = gull.global_position + Vector2(SWAT_STANDOFF, 0)
    seal.facing = -1
    seal.velocity = Vector2.ZERO
    seal.try_swat()
    t.check(swat.is_active(), "갈매기에 꼬리치기가 시동된다")
    await t.step_frames(tree, SWAT_SETTLE_FRAMES)
    t.check(swatted.has("EnemySeagull"), "갈매기에 꼬리치기가 적중한다")
    t.check(gull_knock.size() > 0, "꼬리치기 맞은 갈매기가 제거된다")
    t.check(gull_knock[0] < 0.0, "갈매기가 물범 반대편으로 넉백된다")
    t.approx(gull_knock[0], -SealSwat.KNOCKBACK, 1.0, "갈매기 넉백 속도 220")

    # ── 측면 충돌은 하트 1 (설계 5.3) ──
    # brief의 원문은 물범을 게와 같은 위치에 두고 velocity.y = 300을 줬는데,
    # 이는 "위에서 아래로 떨어지는 밟기"로 읽힌다. 의도인 측면 접촉을 실제로
    # 검사하려면 물범 원점이 게 원점보다 위에 있지 않아야 한다: 게보다 12px
    # 아래에 두고 수직 속도를 0으로 둔다.
    #
    # 먼저 꼬리치기 판정을 끝낸다. 살아 있으면 물범을 게 옆에 두는 순간
    # 판정 영역이 게를 쳐서 queue_free()해 버리고, 이 검사의 의도가 사라진다.
    await t.step_frames(tree, SWAT_EXPIRE_FRAMES)
    GameState.reset_for_level()
    var crab2 := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D
    crab2.global_position = Vector2(0, 0)
    await t.step_frames(tree, 1)
    tree.root.add_child(crab2)
    await t.step_frames(tree, 2)

    seal.global_position = crab2.global_position + Vector2(10, SIDE_OFFSET_Y)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 4)
    t.check(GameState.hearts == 2 and not GameState.is_dead(), "게와 측면에서 부딪히면 하트가 준다")

    # ── 갈매기를 밟아도 사망 (설계 5.3) ──
    GameState.reset_for_level()
    var gull2 := preload("res://scenes/entities/enemy_seagull.tscn").instantiate() as CharacterBody2D
    gull2.global_position = Vector2(400, -100)
    await t.step_frames(tree, 1)
    tree.root.add_child(gull2)
    await t.step_frames(tree, 2)
    seal.global_position = gull2.global_position + Vector2(0, STOMP_DROP)
    seal.velocity = Vector2(0, 300.0)
    await t.step_frames(tree, 4)
    t.check(GameState.is_dead(), "갈매기를 밟아도 사망한다")

    # ── 사망 중 추가 피격은 사망 신호를 반복하지 않는다 ──
    # take_hit이 GameState.is_dead()로 막지 않으면, 하트 0에서의 피격이
    # lose_heart()를 다시 타서 player_died가 두 번 나온다. 즉사 경로(게 밟기)가
    # 생긴 지금은 "하트 0 + 무적 아님"이 레벨 전환 없이도 도달한다.
    var seal3 := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    await t.step_frames(tree, 1)
    tree.root.add_child(seal3)
    await t.step_frames(tree, 2)
    GameState.reset_for_level()
    GameState.die()
    var deaths: int = 0
    GameState.player_died.connect(func() -> void: deaths += 1)
    seal3.take_hit(crab2.global_position)
    t.check(deaths == 0, "사망 중 추가 피격은 사망 신호를 반복하지 않는다")

    for n in [crab2, gull2, seal, seal3]:
        if is_instance_valid(n):
            n.queue_free()

    await _run_no_vertical_drift(t)


# ── 적은 수직으로 표류하지 않는다 (태스크 10 후속 수정 Part B) ──
#
# 게와 갈매기에는 중력이 없다. 그런데 다른 몸체나 지형에 겹쳐서 물리 서버가
# 밀어내면 move_and_slide() 이 그 밀어냄을 velocity.y 에 남긴다. 적 스크립트가
# 이 값을 매 프레임 지우지 않으면, 한 프레임의 밀어냄이 매 프레임 같은 속도로
# 누적돼 적이 레벨 밖으로 영구히 표류한다. 실측: L5 Enemy_5 가 182px 떠오른 뒤
# 돌아오지 못했다. y+는 아래다.
#
# 물리 서버가 velocity.y 에 밀어냄을 쓰는 상황을 재현하려고 여기서는 값을 직접
# 준다(실제로는 서버가 쓴다). 리셋이 있으면 다음 프레임의 move_and_slide() 이
# 수직 이동을 전혀 만들지 않으므로 제자리에 붙어 있고, 리셋이 없으면 400px/s
# 로 끝없이 떠오른다.
func _run_no_vertical_drift(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var bodies := [
        ["crab", preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D],
        ["seagull", preload("res://scenes/entities/enemy_seagull.tscn").instantiate() as CharacterBody2D],
    ]
    for b in bodies:
        var kind: String = str(b[0])
        var node := b[1] as CharacterBody2D
        node.position = Vector2(0, -12 if kind == "crab" else -14)
        await t.step_frames(tree, 1)
        tree.root.add_child(node)
        await t.step_frames(tree, 2)
        var y0: float = node.position.y
        node.velocity = Vector2(0, 400.0)
        await t.step_frames(tree, 60)
        t.check(absf(node.position.y - y0) <= 1.0,
            "%s 에 수직 속도를 줘도 떠내려가지 않는다 (이동 %.2fpx)" % [
                "게" if kind == "crab" else "갈매기", node.position.y - y0])

    for b in bodies:
        var node := b[1] as Node
        if is_instance_valid(node):
            node.queue_free()
    await t.step_frames(tree, 2)
