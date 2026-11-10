extends RefCounted

# 태스크 12: UI 흐름과 레벨 전환 (설계 9.1).
#
# 타이틀 → 레벨 1 → … → 레벨 5 → 완료 화면, 사망 → 제자리 부활 흐름을
# 검사한다. 함께 Task 11 리뷰에서 이 태스크로 넘어온 세 항목 — HUD 레이블
# 배선, GameState.fish_changed, 한국어 폰트 — 도 같은 흐름 위에서 확인한다.
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

    # 진입점은 타이틀 화면이다.
    t.check(main.find_child("Title", true, false) != null, "시작 화면이 뜬다")

    GameState.current_level_index = 1
    main.call("goto_level", 1)
    await t.step_frames(tree, 3)
    var level := main.find_child("Level", true, false) as Node
    t.check(level != null, "레벨 1이 로드된다")
    var seal := main.find_child("BabySeal", true, false) as BabySeal
    t.check(seal != null, "물범이 레벨에 있다")

    # HUD 배선. set_level/set_fish는 level.setup() 반환 이후에 불러야 한다:
    # fish_total은 setup() 안에서 정해지므로 _ready()에서 시드하면 0을 읽는다.
    var hud := main.find_child("Hud", true, false) as Hud
    t.check(hud != null, "HUD가 레벨 안에 붙는다")
    var fish_total: int = GameState.fish_total
    t.check(fish_total > 0, "레벨 1에 물고기가 있다")
    var fish_label: Label = null
    if hud != null:
        var level_label := hud.get_node("LevelLabel") as Label
        fish_label = hud.get_node("FishLabel") as Label
        t.check(level_label != null and level_label.text == "LEVEL 1",
            "HUD 레벨 번호가 LEVEL 1로 표시된다")
        t.check(fish_label != null and fish_label.text == "물고기 0 / %d" % fish_total,
            "HUD 물고기 카운터가 0 / 총계로 표시된다")

    # 물고기 카운터는 픽업 시 갱신된다 (GameState.fish_changed).
    GameState.reset_for_level()
    var fish := preload("res://scenes/entities/pickup_fish.tscn").instantiate() as Area2D
    fish.global_position = seal.global_position
    await t.step_frames(tree, 1)
    tree.root.add_child(fish)
    await t.step_frames(tree, 3)
    t.check(fish_label != null and fish_label.text == "물고기 1 / %d" % fish_total,
        "물고기를 먹으면 HUD 카운터가 오른다")

    # 레벨 1 클리어 → 레벨 2
    GameState.complete_level()
    await t.step_frames(tree, 3)
    t.check(GameState.current_level_index == 2, "레벨 1 클리어 시 레벨 2로 간다")
    # HUD도 레벨 2를 가리킨다. 씬 기본 문자열이 "LEVEL 1"이므로, 이 검사가
    # 빠지면 goto_level의 set_level 호출이 죽은 코드여도 통과한다(뮤테이션 확인).
    var hud2 := main.find_child("Hud", true, false) as Hud
    var level_label2 := hud2.get_node("LevelLabel") as Label if hud2 != null else null
    t.check(level_label2 != null and level_label2.text == "LEVEL 2",
        "레벨 2로 가면 HUD 레벨 번호가 LEVEL 2로 바뀐다")

    # 마지막 레벨 클리어
    GameState.current_level_index = LevelRegistry.level_count()
    GameState.complete_level()
    await t.step_frames(tree, 3)
    var complete_screen := main.find_child("LevelComplete", true, false)
    t.check(complete_screen != null, "마지막 레벨 클리어 시 완료 화면이 뜬다")

    # 사망 → 제자리 부활 (설계 5.5·9.1). 게임오버 화면은 없다.
    #
    # 옛 검사는 "사망 시 게임오버 화면이 뜬다"였다. 그것은 체크포인트 부활이
    # 들어오기 전의 동작이라 지금은 엉뚱한 것을 검증한다: 오버레이의 유일한
    # 버튼은 레벨을 처음부터 다시 조립하므로, 부활이 사용자에게 보이지 않는다.
    # 설계에는 게임오버 모달 개념이 없고 부활 자체가 사망의 메커니즘이므로,
    # 여기서는 실제 사망 경로(player_died)를 타서 부활을 확인한다.
    main.call("goto_level", 2)
    await t.step_frames(tree, 3)
    var death_level := main.find_child("Level", true, false) as Node
    var death_seal := main.find_child("BabySeal", true, false) as BabySeal
    t.check(death_level != null and death_seal != null, "사망 검사용 레벨 2에 물범이 있다")

    # 부활 지점이 체크포인트인지 구분하려면 스폰 뒤쪽 체크포인트를 지나야 한다.
    # 그냥 죽이면 부활 지점이 스폰이라 체크포인트 부활인지 알 수 없다.
    var data2 := LevelRegistry.get_level(2) as LevelData
    var gen_res: Dictionary = LevelGenerator.new().generate(data2)
    var cps: Array = gen_res["checkpoints"] as Array
    gen_res["root"].free()
    var first_cp: Vector2 = (cps[0] as Vector2) if cps.size() > 0 else Vector2.ZERO
    t.check(cps.size() > 0 and first_cp.x > death_seal.global_position.x,
        "레벨 2에 스폰 뒤쪽에 체크포인트가 있다")

    GameState.reset_for_level()
    death_seal.global_position = first_cp
    await t.step_frames(tree, 2)
    t.check((death_level as Node).call("respawn_position") == first_cp,
        "체크포인트를 지나면 부활 지점이 그 체크포인트가 된다")

    # 실제 사망 경로. respawn_at()을 직접 부르지 않고 player_died 를 탄다.
    GameState.die()
    t.check(death_seal.global_position == first_cp,
        "사망 시 마지막으로 통과한 체크포인트에서 제자리 부활한다 (%s)" % str(death_seal.global_position))
    t.check(GameState.hearts == GameState.MAX_HEARTS, "사망 후 하트가 복원된다")
    t.check(main.find_child("GameOver", true, false) == null,
        "사망 시 게임오버 화면이 뜨지 않는다")

    # 재시도
    main.call("retry_level")
    await t.step_frames(tree, 3)
    t.check(GameState.hearts == GameState.MAX_HEARTS, "재시도 시 하트가 복원된다")

    # ── 한국어 폰트 (Task 11 리뷰에서 이 태스크로 넘어온 항목) ──
    # Godot 기본 폰트에는 한글 글리프가 없어 두부(□)로 렌더링된다. 프로젝트
    # 테마가 AppleGothic을 기본 폰트로 얹는지, 화면에 실제로 붙은 레이블과
    # 버튼이 그 폰트를 해석하는지를 본다.
    var theme: Theme = load("res://resources/themes/ui_theme.tres") as Theme
    var korean_font: Font = theme.default_font if theme != null else null
    t.check(korean_font != null, "한국어 테마에 기본 폰트가 있다")
    t.check(_font_has_korean(korean_font), "기본 폰트에 UI가 쓰는 한글 글리프가 모두 있다")

    var hud_now := main.find_child("Hud", true, false) as Hud
    var fish_now: Label = hud_now.get_node("FishLabel") as Label if hud_now != null else null
    t.check(fish_now != null and _font_has_korean(fish_now.get_theme_font("font")),
        "물고기 레이블이 한글 폰트를 해석한다")

    # 세 화면의 버튼 레이블과 폰트. 시작 / 처음부터 다시 / 다시 시도.
    var labels := {
        "res://scenes/ui/title.tscn": "시작",
        "res://scenes/ui/level_complete.tscn": "처음부터 다시",
        "res://scenes/ui/game_over.tscn": "다시 시도",
    }
    for path in labels:
        var screen: Node = (load(path) as PackedScene).instantiate()
        await t.step_frames(tree, 1)
        tree.root.add_child(screen)
        await t.step_frames(tree, 2)
        var button := _first_button(screen)
        t.check(button != null and button.text == labels[path],
            "%s 버튼이 %s 레이블을 가진다" % [path.get_file(), labels[path]])
        t.check(button != null and _font_has_korean(button.get_theme_font("font")),
            "%s 버튼이 한글 폰트를 해석한다" % path.get_file())
        screen.queue_free()
        await t.step_frames(tree, 2)

    main.queue_free()
    await t.step_frames(tree, 2)


# UI가 실제로 쓰는 한글 음절. 글리프가 없으면 두부로 렌더링된다.
func _font_has_korean(font: Font) -> bool:
    if font == null:
        return false
    # "처음부터 다시" 의 처·부·터 도 화면에 실제로 쓰인다.
    for c in ["물", "고", "기", "시", "작", "다", "음", "레", "벨", "도", "처", "부", "터"]:
        if not font.has_char(c.unicode_at(0)):
            return false
    return true


func _first_button(node: Node) -> Button:
    if node is Button:
        return node as Button
    for child in node.get_children():
        var found := _first_button(child)
        if found != null:
            return found
    return null
