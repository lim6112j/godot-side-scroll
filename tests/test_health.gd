extends RefCounted

const INVULNERABLE := 1.2

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    GameState.reset_for_level()
    t.check(GameState.hearts == 3, "시작 하트 3")
    t.check(not GameState.is_dead(), "시작 시 살아있다")

    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D

    # The runner awaits run() from inside _ready(), so the tree is still busy
    # propagating ready notifications here and add_child() would be rejected.
    # Yield one physics frame first so the seal actually enters the tree.
    await t.step_frames(tree, 1)
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
