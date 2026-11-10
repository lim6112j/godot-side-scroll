extends RefCounted

# 사운드 5종 (설계 11장). headless에는 오디오 장치가 없어 실제 소리는 나지 않으므로,
# "올바른 이벤트에서 올바른 이름의 사운드가 재생 신호를 내는지"만 확인한다.
# 소리 자체는 수동 검증에서 듣는다.

const NAMES := ["jump", "swat", "enemy_down", "hurt", "arrive"]

# hurt 의 깜빝임은 투명도 페이드여야 한다 (설계 7.3). BodyPivot 은 VisualSlot 이나
# 도형 파츠가 아닌 피벗이므로 modulate:a 트랙을 갖는 것이 규칙에 맞다. 이 검사가
# 없으면 깜빝임이 스케일 스쿼시로 후퇴해도 초록이 된다.
const BLINK_MIN := 0.5

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
    var tree := Engine.get_main_loop() as SceneTree

    # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
    # 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로 한 프레임 먼저
    # yield 한다 (엔진 규칙 1).
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # GameState는 프로세스 전역 오토로드다. 이 스위트보다 앞서 도는 iceberg 스위트가
    # 하트를 0으로 소진한 채 끝나므로(is_dead() == true), 리셋하지 않으면 아래
    # take_hit()이 조용히 리턴해서 hurt 사운드가 나지 않는다.
    GameState.reset_for_level()

    seal.set_test_floor(true)
    Input.action_press("jump")
    await t.step_frames(tree, 2)
    Input.action_release("jump")
    t.check(played.has("jump"), "점프 시 jump 사운드가 난다")

    # BabySeal.try_swat() 래퍼가 아니라 SealSwat.try_swat()을 직접 부른다.
    # swat 사운드의 주체는 판정을 갖는 SealSwat 쪽이어야, 래퍼를 거치지 않는
    # 호출에서도 소리가 난다.
    (seal.get_node("SealSwat") as SealSwat).try_swat()
    t.check(played.has("swat"), "꼬리치기 시 swat 사운드가 난다")

    seal.take_hit(Vector2(100, 0))
    t.check(played.has("hurt"), "피격 시 hurt 사운드가 난다")

    # 피격의 깜빝임이 투명도 페이드로 구현됐는지. 스케일은 그대로(1, 1)여야 하고
    # modulate.a 가 한 번 이상 절반 이하로 떨어져야 한다.
    var anim := seal.get_node_or_null("SealAnim") as SealAnim
    t.check(anim != null, "SealAnim 노드가 존재한다")
    if anim != null:
        anim.play("hurt")
        var body := seal.get_node("BodyPivot") as Node2D
        var min_alpha: float = body.modulate.a
        var max_scale_x: float = body.scale.x
        var min_scale_x: float = body.scale.x
        for _i in 22:
            await t.step_frames(tree, 1)
            min_alpha = minf(min_alpha, body.modulate.a)
            max_scale_x = maxf(max_scale_x, body.scale.x)
            min_scale_x = minf(min_scale_x, body.scale.x)
        t.check(min_alpha <= BLINK_MIN,
            "피격 깜빝임이 BodyPivot modulate:a 페이드로 구현된다 (최소 투명도 %f)" % min_alpha)
        t.check(max_scale_x - min_scale_x <= 0.01,
            "피격 깜빝임이 스케일 스쿼시가 아니다 (스케일 변화 %f)" % (max_scale_x - min_scale_x))

    var crab := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as Node
    await t.step_frames(tree, 1)
    tree.root.add_child(crab)
    crab.call("_on_swatted")
    t.check(played.has("enemy_down"), "적 제거 시 enemy_down 사운드가 난다")

    GameState.complete_level()
    t.check(played.has("arrive"), "도착 시 arrive 사운드가 난다")

    # 재생기 풀이 헤드리스에서도 회수되는지. 오디오 장치가 없으면 finished 가
    # 나지 않으므로, 수명 기반 회수가 없으면 재생기가 종료까지 남아 ObjectDB
    # 누수가 된다. 가장 긴 소리(arrive 0.6초)의 수명이 지나면 풀이 비어야 한다.
    for _i in 20:
        SoundPlayer.play("arrive")
    var peak: int = SoundPlayer.player_count()
    await t.step_frames(tree, 80)
    t.check(peak > 0 and SoundPlayer.player_count() == 0,
        "재생기 풀이 수명 만료로 회수된다 (최대 %d → 잔여 %d)" % [peak, SoundPlayer.player_count()])

    # 테스트 지면은 queue_free() 전에 직접 걷는다. _exit_tree() 안에서
    # _despawn_test_floor() 가 body.free() 를 부르면 트리가 자식 정리 중이라
    # remove_child() 가 거부되어 exit code 134(SIGABRT) 로 죽는다.
    seal.set_test_floor(false)
    seal.queue_free()
    # crab 은 _on_swatted() 안에서 이미 queue_free() 했다. 80프레임을 더 흘린
    # 뒤에는 실제로 풀려 있으므로, 유효성 검사 없이 부르면 "previously freed
    # instance" 오류가 난다.
    if is_instance_valid(crab):
        crab.queue_free()
    # 이 스위트가 소모한 하트·레벨 인덱스를 원래대로 돌려 다음 스위트를 오염시키지
    # 않는다 (GameState는 씬보다 오래 사는 오토로드다).
    GameState.reset_for_level()
