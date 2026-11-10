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
    t.check(InputMap.has_action("move_left"), "입력 액션 move_left가 등록돼 있다")
    t.check(InputMap.has_action("move_right"), "입력 액션 move_right가 등록돼 있다")
    t.check(InputMap.has_action("retry"), "입력 액션 retry가 등록돼 있다")
    t.check(InputMap.has_action("pause"), "입력 액션 pause가 등록돼 있다")
