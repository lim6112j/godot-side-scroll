class_name Icicle
extends Area2D

# 고드름 (설계 5.3). 천장에 매달려 있다가 플레이어가 아래로 지나가면 낙하하고,
# 맞으면 하트가 준다. y+는 아래이므로 낙하는 양의 position.y.
#
# 매달린 위치는 씬의 CollisionShape2D 오프셋으로 만든다: 노드 원점을 장착점
# (천장)에 두고 shape를 아래로 24px 밀어내면, 원점은 그대로 천장에 남고 몸통만
# 아래로 늘어진다.
#
# 떨어진 뒤에도 제거하지 않는다. brief의 구현이 그대로고, 이미 떨어진 고드름이
# 아래쪽을 지나는 물범을 다시 맞히는 것은 낙하를 피하지 못한 대가로 본다.

@export var fall_speed: float = 260.0

var _falling: bool = false


func _physics_process(delta: float) -> void:
    if not _falling:
        return
    position.y += fall_speed * delta


func _on_body_entered(body: Node) -> void:
    if body is BabySeal:
        _falling = true
        # 대미지를 준다. 고드름은 맞으면 하트가 줄어든다 (설계 5.3).
        # 무적이면 take_hit()이 스스로 삼킨다.
        (body as BabySeal).take_hit(global_position)
