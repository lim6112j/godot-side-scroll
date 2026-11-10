extends RefCounted

const GRAVITY := 900.0
const JUMP_VELOCITY := -320.0

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as BabySeal

    # The runner awaits run() from inside _ready(), so the tree is still busy
    # propagating ready notifications here and add_child() would be rejected.
    # Yield one physics frame first so the seal actually enters the tree.
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # 중력만 작동
    var v0: float = seal.velocity.y
    await t.step_frames(tree, 10)
    t.approx(seal.velocity.y, v0 + GRAVITY * tick * 10, 2.0, "중력이 누적된다")

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
