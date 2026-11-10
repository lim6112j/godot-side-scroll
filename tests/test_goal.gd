extends RefCounted

# 태스크 10: 엄마 물범(목표), 물고기, 레벨 조립.
#
# 설계 5.4 "오른쪽 끝의 엄마에게 도착하면 레벨 클리어", 5.6 "물고기는 클리어
# 조건이 아닌 수집 카운트"를 검사한다. Level.setup()이 생성기 출력을 조립해
# 물범을 돌려주는지, 엄마가 레벨 길이의 90% 이후에 있는지, 도착 판정이
# GameState.level_completed를 내는지, 물고기가 먹히면 GameState.fish_collected가
# 오르고 노드가 제거되는지, celebrate()가 지느러미를 실제로 움직이는지를 본다.
#
# y+는 아래다.

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var level_scene := preload("res://scenes/level/level.tscn").instantiate() as Node
    # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
    # 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로, 한 프레임 먼저
    # yield 한다 (태스크 2 엔진 트랩 1).
    await t.step_frames(tree, 1)
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
    await t.step_frames(tree, 1)
    tree.root.add_child(fish)
    await t.step_frames(tree, 2)
    t.check(GameState.fish_collected == 0, "물고기 수집 전 0")
    seal.global_position = Vector2(100, 0)
    await t.step_frames(tree, 3)
    t.check(GameState.fish_collected == 1, "물고기를 먹으면 1 증가")
    # 제거 증거. queue_free()의 실제 해제는 프레임 말 플러시에서 일어나므로,
    # 여기서는 인스턴스가 이미 없다. "큐에 들어갔는지"를 보면 해제된 인스턴스의
    # 프로퍼티를 읽어 "previously freed" 오류로 스위트가 죽어버리므로, 트리에서
    # 사라졌는지로 확인한다 (test_hazards.gd의 얇은 얼음 항목과 같은 규칙).
    t.check(not is_instance_valid(fish), "먹은 물고기가 제거된다")

    # 엄마의 celebrate
    var flipper := mom.get_node("FlipperPivot") as Node2D
    var rot_before: float = flipper.rotation
    mom.celebrate()
    await t.step_frames(tree, 30)
    t.check(absf(flipper.rotation - rot_before) > 0.001, "celebrate 시 지느러미가 움직인다")

    # ── 체크포인트 부활 (설계 5.5) ──
    # 태스크 13 리뷰에서 넘어온 항목: respawn_at()에 생산 호출이 하나도 없어서
    # 체크포인트가 순전히 장식이었다. 사망 시 마지막으로 통과한 체크포인트로
    # 부활하는지, 그리고 부활 지점이 뒤로 물러나지 않는지를 본다.
    #
    # 위에서 이미 같은 레벨을 클리어했으므로(물범을 엄마 자리로 옮겼다) 체크포인트
    # 추적이 멈춘 상태다. 새 인스턴스로 분리해서 본다.
    #
    # "통과"의 규칙: 물범의 x >= 체크포인트의 x. 체크포인트는 지면 표면(y=0)에
    # 세워지므로 y는 비교하지 않는다 — 공중을 지나가는 것도 지나간 것으로 본다.
    var level2 := preload("res://scenes/level/level.tscn").instantiate() as Node
    await t.step_frames(tree, 1)
    tree.root.add_child(level2)
    await t.step_frames(tree, 2)
    var seal2 := (level2 as Node).call("setup", data) as BabySeal
    var spawn2: Vector2 = seal2.global_position
    var gen := LevelGenerator.new()
    var gen_res: Dictionary = gen.generate(data)
    var cps: Array = gen_res["checkpoints"] as Array
    gen_res["root"].free()
    var first_cp: Vector2 = (cps[0] as Vector2) if cps.size() > 0 else Vector2.ZERO
    t.check(cps.size() == data.checkpoint_count and first_cp.x > spawn2.x,
        "레벨 1에 스폰 뒤쪽에 체크포인트가 있다")

    # 체크포인트를 아직 지나지 않았으면 부활 지점은 레벨 시작점이다.
    seal2.global_position = Vector2(spawn2.x, 0.0)
    await t.step_frames(tree, 2)
    t.check((level2 as Node).call("respawn_position") == spawn2,
        "체크포인트를 지나기 전에는 부활 지점이 스폰이다")

    # 첫 체크포인트를 지난 뒤 사망하면 거기서 부활한다. 위치는 사망 신호 직후에
    # 비교한다: 물범을 체크포인트로 옮기면 그 자리에 서 있던 적에게 닿아 넉백이
    # 붙으므로(체크포인트는 적 회피를 모른다), 프레임을 흘리면 좌표가 흔들린다.
    # 부활 *배선* 은 직후 좌표로, 부활 지점의 *플레이 가능성* 은 착지 후 상태로
    # 각각 확인한다.
    GameState.reset_for_level()
    seal2.global_position = first_cp
    await t.step_frames(tree, 2)
    GameState.die()
    t.check(seal2.global_position == first_cp,
        "사망 시 마지막으로 통과한 체크포인트에서 부활한다 (%s)" % str(seal2.global_position))
    t.check(GameState.hearts == GameState.MAX_HEARTS, "부활 시 하트가 복원된다")
    await t.step_frames(tree, 30)
    t.check(seal2.is_on_floor() and not seal2.is_fallen(),
        "부활 지점에서 물범이 지면에 선다")

    # 부활 지점은 뒤로 물러나지 않는다. 체크포인트 앞쪽(스폰)으로 되돌려 보내도
    # 가장 멀리 간 체크포인트가 남아야 한다 — 그렇지 않으면 구멍에 다시 빠져 죽는
    # 무한 루프가 된다.
    GameState.reset_for_level()
    seal2.global_position = Vector2(spawn2.x, 0.0)
    await t.step_frames(tree, 2)
    t.check((level2 as Node).call("respawn_position") == first_cp,
        "체크포인트를 지난 뒤에는 부활 지점이 뒤로 물러나지 않는다")
    GameState.die()
    t.check(seal2.global_position == first_cp,
        "체크포인트 앞에서 죽어도 마지막 체크포인트에서 부활한다")
    await t.step_frames(tree, 10)

    for n in [level_scene, level2, fish]:
        if is_instance_valid(n):
            n.queue_free()
    await t.step_frames(tree, 2)
    GameState.reset_for_level()
