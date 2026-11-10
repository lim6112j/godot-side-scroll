class_name CameraFollow
extends Node2D

# 수평 추적 카메라 (설계 8.3). 대상의 x 좌표만 따라간다.
#
# 수직은 따라가지 않는다: 설계 8.3은 "수평 추적 + 수직 데드존"을 말하고, 데드존
# 폭은 빌더 재량이다. 발판 고저차(48px/96px)가 화면 높이(360px)에 비해 작아
# 데드존 없이 수직을 고정해도 고저차가 화면 안에 남으므로, 지금은 y를 아예
# 움직이지 않는 쪽을 택했다. 데드존이 필요해지면 그때 _physics_process에
# y 축 분기를 추가한다.
#
# Camera2D 노드에 붙인다. Camera2D는 Node2D를 상속하므로 이 스크립트의 기본
# 타입과 충돌하지 않는다.

@export var target_path: NodePath


func _physics_process(_delta: float) -> void:
    var target := get_node_or_null(target_path) as Node2D
    if target == null:
        return
    global_position.x = target.global_position.x
