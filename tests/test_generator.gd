extends RefCounted

# 레벨 생성기 검증 (태스크 7). 설계의 두 핵심 전제를 기계적으로 확인한다:
#   1) 모든 레벨의 평면 틈이 92px 이하 → 점프만으로 건널 수 있다
#   2) 레벨 2~5에 꼬리치기 강제 수단이 명세된 개수만큼 있다
# 또한 생성기가 개별로 소모하는 컬럼(allows_*, enemy_mix, seed_value)을 실제로
# 반영하는지 확인한다. 합계가 아니라 개별 수로 검사하는 이유는, 벽 하나를 반동
# 틈으로 바꿔도 합이 같으면 통과해버리는 틈을 막기 위해서다.

# 꼬리치기 반동 한 번으로 실제로 건널 수 있는 최대 폭 (실측 142.3px). 물리
# 상한이므로 상수 자체가 여기서 느슨해지는 것도 막는다.
const MEASURED_RECOIL_REACH := 142.0

# 적이 제자리에 붙어 있는지 확인할 때 기다리는 프레임 수. 3초면 게 순찰
# (±80px)과 갈매기 비행(±200px)이 양끝에 한 번씩 도달한다.
const ENEMY_SETTLE_FRAMES := 180
# 배치 y 와 허용되는 차이. 물리 서버가 몸을 표면에 정확히 붙일 때 나오는
# 반 픽셀 이하의 차이만 용용한다.
const ENEMY_Y_TOLERANCE := 1.0
# 적끼리의 최소 중심 거리 (level_generator.gd 의 값과 같은 의미).
const ENEMY_MIN_SPACING := 72.0

func run(t: TestHelper) -> void:
    var gen := LevelGenerator.new()
    t.check(LevelGenerator.RECOIL_REACH_CAP <= MEASURED_RECOIL_REACH + 0.01,
        "반동 틈 폭 상한 %s 이 실측 반동 도달(%s) 이하" % [
            str(LevelGenerator.RECOIL_REACH_CAP), str(MEASURED_RECOIL_REACH)])

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

        # 꼬리치기 강제 수단 개수 (Review Focus 1) — 합이 아니라 개별로
        var walls: int = root.get_meta("swat_wall_count", 0)
        var recoil_gaps: int = root.get_meta("recoil_gap_count", 0)
        t.check(walls == data.swat_wall_count,
            "레벨 %d 얼음 벽 수가 %d (실제 %d)" % [i + 1, data.swat_wall_count, walls])
        t.check(recoil_gaps == data.recoil_gap_count,
            "레벨 %d 반동 틈 수가 %d (실제 %d)" % [i + 1, data.recoil_gap_count, recoil_gaps])

        # recoil_max_gap_px가 0이면 반동 틈을 만들지 않는다
        if data.recoil_max_gap_px <= 0.0:
            t.check(recoil_gaps == 0, "레벨 %d에 반동 틈이 없다" % (i + 1))

        # 반동 틈마다 반동 대상이 앞에 있고, 틈 자체는 점프만으로 못 건너는 폭이면서
        # 반동 한 번으로는 건널 수 있는 폭 (설계 5.8 장치 B)
        for info in root.get_meta("recoil_targets", []):
            t.check(info.has("target"), "레벨 %d 반동 틈에 대상이 있다" % (i + 1))
            t.check(is_instance_valid(info["target"]),
                "레벨 %d 반동 대상 노드가 살아있다" % (i + 1))
            t.check(float(info["gap_width"]) > LevelData.MAX_FLAT_GAP,
                "레벨 %d 반동 틈 폭 %s 이 점프 도달을 넘는다" % [i + 1, str(info["gap_width"])])
            t.check(float(info["gap_width"]) <= LevelGenerator.RECOIL_REACH_CAP + 0.01,
                "레벨 %d 반동 틈 폭 %s 이 반동 한 번 도달(%s) 이하" % [
                    i + 1, str(info["gap_width"]), str(LevelGenerator.RECOIL_REACH_CAP)])

        # 벽은 실제 노드로 앞 1/3에 서 있고, 점프 상승(약 57px)으로 넘을 수 없다
        var swat_nodes: Array = []
        _collect(root, "swat_target", swat_nodes)
        var wall_nodes: Array = []
        for n in swat_nodes:
            if str(n.get_meta("kind", "")) == "ice_wall":
                wall_nodes.append(n)
        t.check(wall_nodes.size() == data.swat_wall_count,
            "레벨 %d 얼음 벽 노드 수가 %d (실제 %d)" % [i + 1, data.swat_wall_count, wall_nodes.size()])
        for n in wall_nodes:
            var x: float = n.position.x
            t.check(x <= data.length_px / 3.0 + 0.01,
                "레벨 %d 얼음 벽 x=%s 가 앞 1/3" % [i + 1, str(x)])
            # 얼음 벽은 이제 hazard_ice_block.tscn 인스턴스다. 씬이 자기 충돌 노드의
            # 이름을 "CollisionShape2D" 로 짓기 때문에, 생성기가 예전에 쓰던
            # "Collision" 이라는 마커 쪽 이름을 찾던 방식을 버리고 형식으로 찾는다.
            # 높이는 씬 기본값(100)에 노드 스케일을 곱한 실효 값으로 본다.
            var shape := _find_collision(n)
            var h := 0.0
            if shape != null and shape.shape is RectangleShape2D:
                h = (shape.shape as RectangleShape2D).size.y * n.scale.y
            t.check(h >= 90.0 and h <= 110.0,
                "레벨 %d 얼음 벽 높이 %s 가 90~110" % [i + 1, str(h)])

        # 체크포인트
        var cps: Array = result["checkpoints"]
        t.check(cps.size() == data.checkpoint_count,
            "레벨 %d 체크포인트 수가 %d (실제 %d)" % [i + 1, data.checkpoint_count, cps.size()])
        var cp_nodes: Array = []
        _collect(root, "checkpoint", cp_nodes)
        t.check(cp_nodes.size() == data.checkpoint_count,
            "레벨 %d 체크포인트 노드 수가 %d (실제 %d)" % [i + 1, data.checkpoint_count, cp_nodes.size()])
        for j in cps.size():
            if j > 0:
                t.check((cps[j] as Vector2).x > (cps[j - 1] as Vector2).x,
                    "레벨 %d 체크포인트가 순서대로 늘어난다" % (i + 1))
            t.check((cps[j] as Vector2).x > 0.0 and (cps[j] as Vector2).x < data.length_px,
                "레벨 %d 체크포인트가 레벨 안에 있다" % (i + 1))

        # 스폰과 목표
        t.check((result["spawn"] as Vector2).x < 600.0, "레벨 %d 스폰이 앞부분" % (i + 1))
        var goal_x: float = result["goal_x"]
        t.check(goal_x > data.length_px * 0.9, "레벨 %d 목표가 길이의 90%% 이후" % (i + 1))
        t.check(goal_x <= data.length_px, "레벨 %d 목표가 레벨 끝을 넘지 않는다" % (i + 1))
        var goal_nodes: Array = []
        _collect(root, "goal", goal_nodes)
        t.check(goal_nodes.size() == 1, "레벨 %d에 목표 노드가 하나" % (i + 1))
        t.check(int(result["fish_total"]) > 0, "레벨 %d에 물고기가 있다" % (i + 1))
        var fish_nodes: Array = []
        _collect(root, "fish", fish_nodes)
        t.check(fish_nodes.size() == int(result["fish_total"]),
            "레벨 %d 물고기 노드 수가 기록과 같다" % (i + 1))

        # 위험 지형: 개수와 허용된 종류만
        var hazard_nodes: Array = []
        _collect(root, "hazard", hazard_nodes)
        t.check(hazard_nodes.size() == data.hazard_count,
            "레벨 %d 위험 지형 수가 %d (실제 %d)" % [i + 1, data.hazard_count, hazard_nodes.size()])
        var kinds: Array = []
        for n in hazard_nodes:
            kinds.append(str(n.get_meta("kind", "")))
        var allowed: Array = []
        if data.allows_thin_ice:
            allowed.append("thin_ice")
        if data.allows_water:
            allowed.append("water")
        if data.allows_icicle:
            allowed.append("icicle")
        for k in kinds:
            t.check(allowed.has(k), "레벨 %d 위험 지형 종류 %s 가 허용 목록에 있다" % [i + 1, str(k)])
        if data.allows_thin_ice:
            t.check(kinds.has("thin_ice"), "레벨 %d에 얇은 얼음이 나온다" % (i + 1))
        if data.allows_water:
            t.check(kinds.has("water"), "레벨 %d에 물이 나온다" % (i + 1))
        else:
            t.check(not kinds.has("water"), "레벨 %d에 물이 없다" % (i + 1))
        if data.allows_icicle:
            t.check(kinds.has("icicle"), "레벨 %d에 고드름이 나온다" % (i + 1))
        else:
            t.check(not kinds.has("icicle"), "레벨 %d에 고드름이 없다" % (i + 1))

        # 위험 요소가 플레이스홀더 마커가 아니라 실제 씬 인스턴스여야 한다.
        # 마커는 "hazard" 그룹에만 들어 있어 kind 메타로 종류를 흉내 내므로, 개수와
        # 종류만 세면 마커와 실제 씬을 구분할 수 없다 (태스크 10 ⚠1).
        for n in hazard_nodes:
            var kind_meta: String = str(n.get_meta("kind", ""))
            var matches := (kind_meta == "thin_ice" and n is ThinIce) \
                or (kind_meta == "water" and n is Water) \
                or (kind_meta == "icicle" and n is Icicle)
            t.check(matches, "레벨 %d 위험 요소 %s 가 실제 씬 인스턴스다" % [i + 1, kind_meta])

        # 꼬리치기 대상(얼음 벽·반동 대상)도 실제 씬이어야 한다. 날 StaticBody2D는
        # 꼬리치기를 받아도 사라지지 않아 레벨이 막힌다.
        for n in swat_nodes:
            t.check(n is IceBlock, "레벨 %d 꼬리치기 대상이 IceBlock 씬이다 (%s)" % [i + 1, str(n)])

        # ── 얇은 얼음이 깨지면 실제로 추락한다 (설계 5.3, 태스크 10 ⚠2) ──
        # ThinIce는 Area2D라 서 있을 표면이 아니다. 서게 해 주는 것은 레벨 지면이므로,
        # 생성기는 얇은 얼음 자리의 지면을 별도 조각(IceFloor)으로 떼어 두고 깨질 때
        # 함께 치운다. 여기서는 그 구조가 실제로 만들어지는지 확인한다.
        var ground := _ground_intervals(root)
        for n in hazard_nodes:
            if not (n is ThinIce):
                continue
            var nx: float = n.position.x
            var support := _covering_interval(ground, nx, true)
            t.check(not support.is_empty(),
                "레벨 %d 얇은 얼음 아래에 따로 떼어 낸 지면이 있다" % (i + 1))
            if not support.is_empty():
                t.check(float(support["x1"]) - float(support["x0"]) >= LevelGenerator.HAZARD_FOOTPRINT - 0.01,
                    "레벨 %d 얇은 얼음 지면 조각이 발자국을 덮는다" % (i + 1))
            # 같은 자리에 일반 지면이 덧깔려 있으면 무너져도 버틴다.
            var plain := _covering_interval(ground, nx, false)
            t.check(plain.is_empty(),
                "레벨 %d 얇은 얼음 자리에 일반 지면이 겹치지 않는다" % (i + 1))
        for n in hazard_nodes:
            if not (n is Water):
                continue
            # 물은 빙하 틈이므로 그 자리에는 지면이 없어야 떨어진다.
            t.check(_covering_interval(ground, float(n.position.x), false).is_empty()
                and _covering_interval(ground, float(n.position.x), true).is_empty(),
                "레벨 %d 물 자리에 지면이 없다 (빙하 틈)" % (i + 1))

        # 적: enemy_mix 안의 종류만, 앞 1/3은 밀도의 30%
        var enemy_nodes: Array = []
        _collect(root, "enemy", enemy_nodes)
        t.check(enemy_nodes.size() > 0, "레벨 %d에 적이 있다" % (i + 1))
        var enemy_kinds: Array = []
        for n in enemy_nodes:
            enemy_kinds.append(str(n.get_meta("kind", "")))
        for k in enemy_kinds:
            t.check(data.enemy_mix.has(k), "레벨 %d 적 종류 %s 가 enemy_mix 에 있다" % [i + 1, str(k)])
        if data.enemy_mix.size() > 1:
            for k in data.enemy_mix:
                t.check(enemy_kinds.has(k), "레벨 %d에 %s 가 등장한다" % [i + 1, str(k)])
        else:
            t.check(enemy_kinds.has(data.enemy_mix[0]),
                "레벨 %d에 %s 가 등장한다" % [i + 1, str(data.enemy_mix[0])])

        # 적도 플레이스홀더 마커가 아니라 실제 씬 인스턴스여야 한다 (태스크 10 리뷰).
        # 마커는 "enemy" 그룹에만 들어 있어 kind 메타로 종류를 흉내 내므로, 개수와
        # 종류만 세면 마커와 실제 씬을 구분할 수 없다. 마커로 두면 게임에 적이 한
        # 마리도 나타나지 않아 꼬리치기 강제 장치(설계 5.3)가 사라진다.
        for n in enemy_nodes:
            var ekind: String = str(n.get_meta("kind", ""))
            var is_scene := (ekind == "crab" and n is EnemyCrab) \
                or (ekind == "seagull" and n is EnemySeagull)
            t.check(is_scene, "레벨 %d 적 %s 가 실제 씬 인스턴스다" % [i + 1, ekind])

        var front_limit := data.length_px / 3.0
        var front_count := 0
        var back_count := 0
        for n in enemy_nodes:
            if n.position.x < front_limit:
                front_count += 1
            else:
                back_count += 1
        var front_span := maxf(front_limit - 600.0, 1.0)
        var back_span := maxf(data.length_px - 300.0 - front_limit, 1.0)
        t.check(float(front_count) / front_span <= float(back_count) / back_span * 1.1 + 0.001,
            "레벨 %d 앞 1/3 적 밀도가 뒤보다 낮다 (%d/%d)" % [i + 1, front_count, back_count])

        # 결정성
        var again: Dictionary = gen.generate(data)
        t.check((again["spawn"] as Vector2) == (result["spawn"] as Vector2),
            "레벨 %d 생성이 결정적이다 (스폰 일치)" % (i + 1))
        t.check(float(again["goal_x"]) == goal_x, "레벨 %d 생성이 결정적이다 (목표 일치)" % (i + 1))
        t.check(_same(again["root"].get_meta("flat_gaps", []), gaps),
            "레벨 %d 생성이 결정적이다 (평면 틈 일치)" % (i + 1))
        t.check(int(again["fish_total"]) == int(result["fish_total"]),
            "레벨 %d 생성이 결정적이다 (물고기 수 일치)" % (i + 1))
        (again["root"] as Node2D).free()

        # 시드를 바꾸면 지형이 달라진다 (seed_value 가 실제로 소모된다)
        var other := data.duplicate() as LevelData
        other.seed_value = data.seed_value + 7
        var shifted: Dictionary = gen.generate(other)
        t.check(not _same(shifted["root"].get_meta("flat_gaps", []), gaps),
            "레벨 %d 시드를 바꾸면 평면 틈이 달라진다" % (i + 1))
        t.check(int(shifted["fish_total"]) > 0, "레벨 %d 다른 시드에도 물고기가 있다" % (i + 1))
        (shifted["root"] as Node2D).free()

        root.free()

    await _run_enemy_placement(t)


# ── 생성한 레벨을 씬 트리에 넣어도 적이 제자리에 붙어 있다 ──
#
# 이 단정이 없던 동안 709개 체크가 전부 통과하는 와중에도 적은 레벨 밖으로
# 표류하고 있었다. 이유는 모든 스위트가 생성 루트를 씬 트리에 넣지 않아서,
# 적(CharacterBody2D)의 물리가 한 번도 돌지 않았기 때문이다.
#
# 실제로 일어난 일: _add_enemy 가 반동 대상·다른 적과 겹친 자리에 적을 놓았다.
# 물리 서버가 겹침을 풀면서 한쪽을 밀어내고, move_and_slide() 이 그 밀어냄을
# velocity.y 에 남겼다. 적 스크립트에 중력이 없어 그 값이 리셋되지 않으므로
# 매 프레임 같은 속도로 더 밀려나, L5 Enemy_5 는 182px 떠오른 뒤 레벨 밖으로
# 영구히 나갔다. y+는 아래다.
func _run_enemy_placement(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    for i in 5:
        var data := LevelRegistry.get_level(i + 1) as LevelData
        var level_scene := preload("res://scenes/level/level.tscn").instantiate() as Node
        # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행
        # 중이다. 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로,
        # 한 프레임 먼저 yield 한다 (태스크 2 엔진 트랩 1).
        await t.step_frames(tree, 1)
        tree.root.add_child(level_scene)
        await t.step_frames(tree, 2)
        var seal := (level_scene as Node).call("setup", data) as BabySeal
        t.check(seal != null, "레벨 %d 조립이 물범을 반환한다" % (i + 1))

        var enemies: Array = []
        _collect(level_scene, "enemy", enemies)
        t.check(enemies.size() > 0, "레벨 %d 에 적이 있다" % (i + 1))
        var intended: Array = []
        var xs: Array = []
        for e in enemies:
            intended.append((e as Node2D).position.y)
            xs.append((e as Node2D).position.x)

        await t.step_frames(tree, ENEMY_SETTLE_FRAMES)
        var worst := 0.0
        for j in enemies.size():
            var d: float = absf((enemies[j] as Node2D).position.y - float(intended[j]))
            worst = maxf(worst, d)
        t.check(worst <= ENEMY_Y_TOLERANCE,
            "레벨 %d 적이 배치 y 에서 %spx 이상 벗어나지 않는다 (최대 %.2fpx)" % [
                i + 1, str(ENEMY_Y_TOLERANCE), worst])

        # 적끼리가 겹쳐 태어나면 안 된다. 몸체는 게 32·갈매기 36 폭이므로 중심
        # 거리가 36 미만이면 겹친다. 생성기는 ENEMY_MIN_SPACING(72)을 목표로
        # 하고, 밀도가 높아 못 채우는 구간에서만 겹치지 않는 하한(40)까지 내린다.
        var min_ee := INF
        for a in xs.size():
            for b in range(a + 1, xs.size()):
                min_ee = minf(min_ee, absf(float(xs[a]) - float(xs[b])))
        t.check(min_ee >= 36.0,
            "레벨 %d 적끼리 겹치지 않는다 (최소 중심 거리 %.1fpx)" % [i + 1, min_ee])

        level_scene.queue_free()
        await t.step_frames(tree, 2)


func _collect(node: Node, group: String, out: Array) -> void:
    if node.is_in_group(group):
        out.append(node)
    for c in node.get_children():
        _collect(c, group, out)


# 노드의 자식 중 CollisionShape2D 를 하나 찾는다. 이름으로 찾지 않는 이유: 실제
# 씬(hazard_ice_block.tscn)은 자기 충돌 노드를 "CollisionShape2D" 라 하므로,
# 생성기가 예전에 쓰던 "Collision" 이라는 쪽 이름에 의존하면 씬이 바뀔 때 테스트가
# 깨진다.
func _find_collision(node: Node) -> CollisionShape2D:
    for c in node.get_children():
        var shape := c as CollisionShape2D
        if shape != null:
            return shape
    return null


# 레벨의 지면 조각들을 x 구간 배열로 모은다. is_support=true 는 얇은 얼음 아래에
# 따로 떼어 낸(IceFloor) 조각만, false 는 일반 지면(Ground)만 고른다.
#
# ThinIce는 Area2D라 서 있을 표면이 아니다. "밟으면 0.3초 후 깨지고 추락"
# (설계 5.3)이 성립하려면 깨지는 순간 서 있던 표면이 함께 사라져야 하므로, 생성기는
# 얇은 얼음 자리의 지면을 별도 조각으로 떼어 두고 collapsed 신호로 함께 치운다.
# 이 두 배열을 비교하면 그 구조가 실제로 만들어졌는지 알 수 있다.
func _ground_intervals(root: Node) -> Array:
    var out: Array = []
    for c in root.get_children():
        _ground_intervals_of(c, out)
    return out


func _ground_intervals_of(node: Node, out: Array) -> void:
    if node is StaticBody2D:
        var name_str: String = node.name
        var is_support := name_str.begins_with("IceFloor")
        if is_support or name_str.begins_with("Ground"):
            var shape := _find_collision(node)
            if shape != null and shape.shape is RectangleShape2D:
                var w: float = (shape.shape as RectangleShape2D).size.x
                var cx: float = node.position.x
                out.append({"x0": cx - w * 0.5, "x1": cx + w * 0.5, "support": is_support})
    for c in node.get_children():
        _ground_intervals_of(c, out)


# x 를 덮는 지면 구간을 하나 돌려준다. support_only 로 IceFloor 조각만 고를 수 있다.
func _covering_interval(intervals: Array, x: float, support_only: bool) -> Dictionary:
    for r: Dictionary in intervals:
        if support_only and not bool(r["support"]):
            continue
        if (not support_only) and bool(r["support"]):
            continue
        if x >= float(r["x0"]) - 0.001 and x <= float(r["x1"]) + 0.001:
            return r
    return {}


func _same(a: Array, b: Array) -> bool:
    if a.size() != b.size():
        return false
    for i in a.size():
        if absf(float(a[i]) - float(b[i])) > 0.001:
            return false
    return true
