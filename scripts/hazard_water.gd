class_name Water
extends Area2D

# 물 / 빙하 틈 (설계 5.3). 닿으면 즉사. 하트를 깎는 경로가 아니다: 물은 "떨어져
# 죽는다"는 기존 메커닉의 시각적 표현이므로 GameState.die()로 하트를 한 번에
# 0으로 만든다 (설계 6.1).
#
# Area2D가 아니라 StaticBody2D가 아닌 이유: 물에 빠지면 아래로 떠내려가야 하므로
# 물 자체는 밟히면 안 된다. 겹침만 감시한다.

func _on_body_entered(body: Node) -> void:
    if not (body is BabySeal):
        return
    GameState.die()
