class_name ThinIce
extends Area2D

# 얇은 얼음 (설계 5.3). 밟으면 0.3초 뒤에 깨진다. 예고는 금 간 표면으로 하고,
# 여기서는 시간만 잰다: 판정 영역이 이미 지나간 뒤에야 무너지므로, 물범은
# "밟고 잠깐 더 갈 수 있다"는 착각을 하게 된다.
#
# Area2D인 이유: 지면 그 자체가 아니라 그 위를 덮는 표면이다. 실제로 서 있는
# 물리 지면은 레벨 씬의 StaticBody2D가 맡으므로, 여기서는 겹침만 감시한다.

signal collapsed

@export var collapse_delay: float = 0.3

# -1은 "아직 밟히지 않음". 0 이상이면 남은 시간. collapse_delay가 0이면
# _on_body_entered가 0을 넣고 다음 프레임에 바로 무너진다.
var _timer: float = -1.0


func _physics_process(delta: float) -> void:
    if _timer < 0.0:
        return
    _timer -= delta
    if _timer <= 0.0:
        collapsed.emit()
        queue_free()


# 한 번 밟히면 다시 누적하지 않는다. 두 번째 밟기는 이미 깨지는 중이므로.
func _on_body_entered(body: Node) -> void:
    if body is BabySeal and _timer < 0.0:
        _timer = collapse_delay
