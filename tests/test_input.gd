extends RefCounted

# 설계 10장: 재시도(R)와 일시정지(Esc) 도 실제 입력으로 소비돼야 한다.
# project.godot 에 두 액션이 등록돼 있는 것은 test_smoke.gd 가 이미 보지만,
# 거기서는 "존재"만 보므로 아무도 읽지 않는 액션도 통과한다 — 실제로 둘 다
# production 에 배선되지 않은 채로 전 스위트가 초록이었다. 여기서는 반대쪽을
# 잠근다: 키를 누르면 각각 의도한 효과가 나야 한다.
#
# y+는 아래다.

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var main := preload("res://scenes/main.tscn").instantiate() as Node

    # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
    # 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로, 한 프레임 먼저
    # yield 한다 (태스크 2 엔진 트랩 1).
    await t.step_frames(tree, 1)
    tree.root.add_child(main)
    await t.step_frames(tree, 2)

    GameState.current_level_index = 3
    main.call("goto_level", 3)
    await t.step_frames(tree, 3)
    var seal_before := main.find_child("BabySeal", true, false) as BabySeal
    t.check(seal_before != null, "레벨 3에 물범이 있다")

    # 일시정지가 세계를 실제로 멈추는지 보려면 물범을 공중에 띄워 둔다. 지면에
    # 서 있으면 멈춘 동안에도 가만히 있으므로 "멈췄다"와 "그냥 정지"를 구분할 수
    # 없다.
    seal_before.global_position += Vector2(0, -80)
    seal_before.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)

    # ── 일시정지 (Esc) ──
    t.check(not tree.paused, "시작 시 일시정지가 아니다")
    t.check(main.find_child("Pause", true, false) == null, "오버레이가 아직 없다")

    Input.action_press("pause")
    # action_press() 은 물리 프레임을 돌리지 않는다. 입력을 읽는 곳은 Main 의
    # _physics_process 이므로, 이 시점에서는 아무 일도 일어나지 않아야 한다.
    t.check(not tree.paused, "입력을 눌러도 프레임을 돌리기 전에는 일시정지가 아니다")
    await t.step_frames(tree, 1)
    t.check(tree.paused, "Esc 를 누르면 한 물리 프레임 만에 일시정지가 걸린다")

    var overlay := main.find_child("Pause", true, false) as PauseOverlay
    t.check(overlay != null, "일시정지 오버레이가 뜬다")
    # 트리가 멈춘 동안에도 입력을 읽고 버튼이 눌려야 하므로 ALWAYS 여야 한다.
    # INHERIT 로 두면 Main 의 PAUSABLE 을 물려받아 버튼도 에지도 죽는다.
    t.check(overlay != null and overlay.process_mode == Node.PROCESS_MODE_ALWAYS,
        "오버레이가 PROCESS_MODE_ALWAYS 라 트리가 멈춰도 동작한다")
    var resume_button: Button = null
    if overlay != null:
        resume_button = overlay.get_node_or_null("Box/ResumeButton") as Button
    t.check(resume_button != null and resume_button.text == "계속",
        "오버레이에 계속 버튼이 있다")
    t.check(resume_button != null and resume_button.process_mode == Node.PROCESS_MODE_ALWAYS,
        "계속 버튼도 PROCESS_MODE_ALWAYS 다")

    # 일시정지가 실제로 세계를 멈추는지: 프레임을 흘려도 물범이 떨어지지 않는다.
    var y_at_pause: float = seal_before.global_position.y
    await t.step_frames(tree, 10)
    t.check(seal_before.global_position.y == y_at_pause,
        "일시정지 중 물리 세계가 멈춘다 (y %f 고정)" % y_at_pause)

    # Esc 로 닫기. 오버레이가 뜬 프레임에도 그 키는 아직 눌려 있으므로, 먼저
    # 떼는 상태를 한 프레임 반영한 뒤 다시 눌러야 상승 에지가 된다.
    Input.action_release("pause")
    await t.step_frames(tree, 2)
    t.check(tree.paused, "키를 떼도 일시정지는 유지된다")
    Input.action_press("pause")
    await t.step_frames(tree, 1)
    Input.action_release("pause")
    t.check(not tree.paused, "Esc 로 다시 누르면 일시정지가 풀린다")
    t.check(main.find_child("Pause", true, false) == null, "닫으면 오버레이가 사라진다")
    # 풀린 뒤에는 세계가 다시 돈다. 이 검사가 없으면 "멈춘 채로 아무 일도 안 함"
    # 도 일시정지 해제로 통과한다.
    await t.step_frames(tree, 10)
    t.check(seal_before.global_position.y > y_at_pause,
        "일시정지를 풀면 물리 세계가 다시 돈다 (y %f → %f)"
            % [y_at_pause, seal_before.global_position.y])

    # 버튼으로도 닫힌다.
    await t.step_frames(tree, 2)
    Input.action_press("pause")
    await t.step_frames(tree, 1)
    Input.action_release("pause")
    t.check(tree.paused, "다시 일시정지를 걸 수 있다")
    var overlay2 := main.find_child("Pause", true, false) as PauseOverlay
    var button2: Button = null
    if overlay2 != null:
        button2 = overlay2.get_node_or_null("Box/ResumeButton") as Button
    t.check(button2 != null, "두 번째 오버레이에도 계속 버튼이 있다")
    if button2 != null:
        button2.pressed.emit()
    t.check(not tree.paused, "계속 버튼을 누르면 일시정지가 풀린다")
    await t.step_frames(tree, 2)
    t.check(main.find_child("Pause", true, false) == null, "버튼으로 닫으면 오버레이가 사라진다")

    # ── 재시도 (R) ──
    # "레벨을 다시 조립한다"는 것은 새 Level 인스턴스와 새 물범이 생긴다는 뜻이다.
    # goto_level이 옛 레벨을 트리에서 바로 떼므로 인스턴스가 갈린다.
    GameState.hearts = 1
    var index_before: int = GameState.current_level_index
    Input.action_press("retry")
    t.check(GameState.hearts == 1, "프레임을 돌리기 전에는 재시도가 아니다 (하트 그대로)")
    await t.step_frames(tree, 1)
    Input.action_release("retry")
    await t.step_frames(tree, 3)
    var seal_after := main.find_child("BabySeal", true, false) as BabySeal
    t.check(seal_after != null and seal_after != seal_before,
        "R 을 누르면 레벨이 다시 조립된다 (새 물범 인스턴스)")
    t.check(GameState.current_level_index == index_before,
        "재시도는 현재 레벨 인덱스(%d)를 유지한다" % index_before)
    t.check(GameState.hearts == GameState.MAX_HEARTS,
        "재시도 시 하트가 복원된다 (실제 %d)" % GameState.hearts)
    # 옛 물범이 트리에 남아 있으면 재시도가 아니라 중복이다.
    t.check(main.find_child("Level", true, false) != null, "재시도 후에도 레벨이 하나다")

    main.queue_free()
    await t.step_frames(tree, 2)
