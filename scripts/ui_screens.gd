class_name UiScreens
extends RefCounted

# UI 화면 보관함 (태스크 12). scenes/ui/ 의 세 화면을 인스턴스화해 Main 아래에
# 붙이고, 새 화면을 띄울 때 옛 화면을 해제한다.
#
# 책임 분리: 화면 안에 무엇을 그릴지는 각 .tscn이 갖고, 이 스크립트는 "어느
# 화면을 언제 띄우고 버튼을 어느 함수에 연결하는지"만 안다. 흐름 자체는
# main.gd가 정하므로 여기서는 GameState를 읽지 않는다.

const TITLE_SCENE := preload("res://scenes/ui/title.tscn")
const LEVEL_COMPLETE_SCENE := preload("res://scenes/ui/level_complete.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/game_over.tscn")

# 화면 루트 노드 이름. find_child로 찾으므로 씬의 루트 이름과 같아야 한다.
const TITLE_NAME := "Title"
const LEVEL_COMPLETE_NAME := "LevelComplete"
const GAME_OVER_NAME := "GameOver"

var _owner: Node = null
var _current: Node = null


func _init(owner: Node) -> void:
    _owner = owner


func show_title() -> void:
    _attach(TITLE_SCENE, TITLE_NAME, "StartButton", "start_game")


func show_level_complete() -> void:
    _attach(LEVEL_COMPLETE_SCENE, LEVEL_COMPLETE_NAME, "NextButton", "next_level")


func show_game_over() -> void:
    _attach(GAME_OVER_SCENE, GAME_OVER_NAME, "RetryButton", "retry_level")


func hide_all() -> void:
    if _current == null:
        return
    # queue_free()만 하면 프레임 말까지 트리에 남는다. 트리에서 바로 떼야
    # 다음 화면이나 find_child가 옛 화면을 집어오지 않는다.
    if _current.is_inside_tree():
        _owner.remove_child(_current)
    _current.queue_free()
    _current = null


# 이름이 같은 화면이 이미 떠 있는지. main.gd가 게임오버 화면을 두 번 띄우는
# 것을 막는 가드로 쓴다.
func is_showing(screen_name: String) -> bool:
    return _current != null and _current.name == screen_name


func _attach(scene: PackedScene, screen_name: String, button_name: String, method: String) -> void:
    hide_all()
    var screen := scene.instantiate() as Node
    screen.name = screen_name
    _owner.add_child(screen)
    _current = screen
    var button := screen.find_child(button_name, true, false) as Button
    if button != null:
        button.pressed.connect(Callable(_owner, method))
