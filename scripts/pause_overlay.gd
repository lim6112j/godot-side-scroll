class_name PauseOverlay
extends CanvasLayer

# 일시정지 오버레이 (설계 10장: Esc). Main이 get_tree().paused = true 를 걸고
# 이 레이어를 붙인다. "계속" 버튼이나 Esc 로 닫으면 paused = false 가 풀린다.
#
# 이 노드와 그 자식들은 PROCESS_MODE_ALWAYS 로 고정한다. 트리가 멈춘 동안에도
# 입력을 읽고 버튼이 눌려야 하므로, INHERIT( Main 의 PAUSABLE 물려받음)로 두면
# 버튼도 에지도 죽은 UI 가 된다.

# 닫기 키의 상승 에지. 점프·꼬리치기와 같은 폴링 이유로 is_action_just_pressed()
# 를 쓰지 않는다 (seal_baby.gd 주석).
var _pause_was_down: bool = false


func _ready() -> void:
    # 일시정지를 연 그 키를 곧바로 닫기 키로 읽지 않는다. 오버레이가 뜨는
    # 프레임에도 그 키는 아직 눌려 있으므로, 첫 프레임의 상승 에지로 resume() 이
    # 걸리면 Esc 한 번에 열고 닫는 셈이 된다.
    _pause_was_down = Input.is_action_pressed("pause")

    var button := get_node_or_null("Box/ResumeButton") as Button
    if button != null:
        button.pressed.connect(resume)


func _physics_process(_delta: float) -> void:
    var pause_down := Input.is_action_pressed("pause")
    if pause_down and not _pause_was_down:
        resume()
    _pause_was_down = pause_down


func resume() -> void:
    get_tree().paused = false
    # 트리에서 바로 떼어 해제 큐에 넣는다. queue_free()만 하면 프레임 말까지
    # 남아 find_child("Pause") 가 이미 닫힌 오버레이를 집어온다.
    if is_inside_tree():
        get_parent().remove_child(self)
    queue_free()
