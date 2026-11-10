extends RefCounted

# 태스크 11: HUD (하트·레벨 번호·물고기 카운터).
#
# 설계 5.3 "하트 3개"와 5.6 "물고기 N / M" 표시를 검사한다. 하트는
# GameState.hearts_changed를 구독해 컨테이너의 노드 수가 실제로 바뀌는지를
# 보고, 두 Label은 set_level/set_fish가 쓴 문자열을 그대로 확인한다.
#
# y+는 아래다.

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    # GameState는 오토로드 싱글톤이라 앞선 스위트가 남긴 하트가 섞인다.
    # 초기 "하트 3개"를 단정하려면 먼저 리셋해 MAX로 맞춘다. 건드린 값은
    # 마지막에 되돌려 뒤따르는 스위트를 오염시키지 않는다.
    var fish_total_before: int = GameState.fish_total
    GameState.reset_for_level()

    var hud := preload("res://scenes/ui/hud.tscn").instantiate() as CanvasLayer
    # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
    # 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로, 한 프레임
    # 먼저 yield 한다 (태스크 2 엔진 트랩 1).
    await t.step_frames(tree, 1)
    tree.root.add_child(hud)
    await t.step_frames(tree, 2)

    t.check(hud.get_heart_count() == 3, "초기 하트 3개")

    hud.set_level(2)
    hud.set_fish(3, 7)
    var level_label := hud.get_node("LevelLabel") as Label
    var fish_label := hud.get_node("FishLabel") as Label
    t.check(level_label != null and level_label.text == "LEVEL 2",
        "레벨 번호가 LEVEL 2로 표시된다")
    t.check(fish_label != null and fish_label.text == "물고기 3 / 7",
        "물고기 카운터가 물고기 3 / 7로 표시된다")

    GameState.hearts_changed.emit(1)
    await t.step_frames(tree, 2)
    t.check(hud.get_heart_count() == 1, "hearts_changed 시 하트가 1로 줄어든다")

    GameState.hearts_changed.emit(3)
    await t.step_frames(tree, 2)
    t.check(hud.get_heart_count() == 3, "hearts_changed 시 하트가 3으로 회복된다")

    # 뒷정리: HUD를 트리에서 떼고 GameState를 원래 값으로 되돌린다.
    GameState.fish_total = fish_total_before
    GameState.reset_for_level()
    hud.queue_free()
    await t.step_frames(tree, 2)
