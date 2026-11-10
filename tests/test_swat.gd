extends RefCounted

# Godot 2D: y+ is DOWN. Lifting the seal upward means a negative velocity.y, the
# same convention as BabySeal.JUMP_VELOCITY (-320).
const SWAT_RECOIL := -150.0

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D

    # The runner awaits run() from inside _ready(), so the tree is still busy
    # propagating ready notifications here and add_child() would be rejected.
    # Yield one physics frame first so the seal actually enters the tree.
    await t.step_frames(tree, 1)
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
    # 직전 재시동(위 try_swat)이 쿨다운(0.40초)을 건 상태이므로, 먼저 만료시킨다.
    # 그렇지 않으면 아래 seal.try_swat()이 쿨다운에 막혀 조차 통과하지 못하고,
    # is_active()는 직전 시동 덕에 참이 되어 이 블록은 절대 실패할 수 없다.
    await t.step_frames(tree, 25)
    seal.velocity = Vector2(0, -100)
    seal.facing = 1
    # swat.try_swat()가 아니라 BabySeal.try_swat() 래퍼를 호출한다. 이후 작업이
    # 부르는 것은 래퍼이며, SealSwat 위임·set_direction·swat 애니메이션·공중 밀기를
    # 모두 여기서 검증해야 한다.
    seal.try_swat()
    t.check(swat.is_active(), "공중에서도 꼬리치기가 활성화된다")
    var seal_anim := seal.get_node_or_null("SealAnim") as SealAnim
    t.check(seal_anim != null and seal_anim.current() == "swat",
        "꼬리치기 시 swat 애니메이션이 재생된다")
    # 시작 velocity.x가 0이므로 공중 밀기는 정확히 +40에 착륙한다.
    t.check(absf(seal.velocity.x - 40.0) <= 0.01,
        "공중 꼬리치기 시 SWAT_PUSH(+40)가 적용된다 (실제 %f)" % seal.velocity.x)
    t.check(seal.facing == 1, "공중 꼬리치기 후에도 facing이 +1을 유지한다")
    await t.step_frames(tree, 1)
    t.check(swat.get_hitbox().position.x > 0.0,
        "히트박스가 전방으로 배치된다 (실제 %f)" % swat.get_hitbox().position.x)

    # 지면 제동: 지면에서 쓰면 0.15초간 마찰이 3배가 된다 (설계 5.2).
    await t.step_frames(tree, 25)
    seal.set_test_floor(true)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)
    t.check(seal.is_on_floor(), "제동 테스트를 위해 지면에 닿아 있다")
    var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
    seal.velocity = Vector2(100, 0)
    seal.try_swat()
    await t.step_frames(tree, 1)
    var brake_drop: float = 100.0 - seal.velocity.x
    t.check(brake_drop > BabySeal.GROUND_FRICTION * tick,
        "지면 꼬리치기 시 마찰 제동이 3배로 적용된다 (감속 %f > %f)"
            % [brake_drop, BabySeal.GROUND_FRICTION * tick])

    # 반동 블록은 원래대로 지면 없이 진행되어야 하므로 테스트 지면을 걷는다.
    seal.set_test_floor(false)

    # 반동: 히트 시 위로 150px/s.
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

    # ── 입력 소비 회귀 (C1) ──
    # project.godot 에 swat 액션이 등록돼 있는 것은 test_smoke.gd 가 이미 본다.
    # 거기서는 "존재"만 보므로, 아무도 읽지 않는 액션도 통과한다 — 실제로
    # 꼬리치기 입력이 production 에 배선되지 않은 채로 전 스위트가 초록이었다.
    # 여기서는 반대쪽을 잠근다: 액션을 누르면 BabySeal._physics_process 가 이를
    # 읽어 꼬리치기가 발동해야 한다.
    #
    # 위 반동 블록의 시동이 쿨다운(0.40초)을 건 상태이므로 먼저 만료시킨다.
    # 만료 전이면 아래 활성화 검사가 쿨다운에 막혀 실패하므로, 쿨다운 종료를
    # 따로 확인해 이 블록이 공허해지는 것을 막는다.
    await t.step_frames(tree, 30)
    t.check(not swat.is_active(), "입력 전 꼬리치기가 비활성이다")
    t.check(not swat.is_on_cooldown(), "입력 전 쿨다운이 끝나 있다")

    Input.action_press("swat")
    # action_press() 은 물리 프레임을 돌리지 않는다. 입력을 읽는 곳은
    # _physics_process 이므로, 이 시점에서는 아직 발동 전이다.
    t.check(not swat.is_active(), "입력을 눌러도 프레임을 돌리기 전에는 비활성")
    await t.step_frames(tree, 1)
    t.check(swat.is_active(), "swat 입력을 누르면 한 물리 프레임 만에 발동한다")
    # 뒤따르는 스위트를 위해 누름을 떼고, 떼는 상태가 _swat_was_down 에 반영될
    # 프레임을 하나 흘린다.
    Input.action_release("swat")
    await t.step_frames(tree, 2)

    dummy.queue_free()
    seal.queue_free()
