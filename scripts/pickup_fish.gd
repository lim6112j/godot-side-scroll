class_name Fish
extends Area2D

# 물고기 (설계 5.6). 길에 배치되는 수집품. 클리어 조건이 아니므로 카운트만
# GameState에 올리고 노드는 사라진다.
#
# 카운팅을 Fish 자신이 하는 이유: 레벨 트리 밖에서 단독으로 인스턴스화해도
# (테스트, 장식 배치) 동작해야 하고, 구독자를 Level에 두면 그 경우 카운트가
# 누락된다. "먹었다"는 사실의 소유자는 물고기 자신이다.

signal collected


# 카운팅은 GameState가 하지만 "먹혔다"는 사실의 발신자는 이 노드다. 레벨 트리
# 밖에서 단독으로 인스턴스화해도(테스트·장식 배치) 세어져야 하므로, 자신의
# 시그널에 GameState.collect_fish()를 걸어 둔다. collect_fish()가 fish_changed를
# 내므로 HUD 카운터도 함께 갱신되고, 외부에서 collected를 더 구독해도(획득 연출
# 등) 카운트는 한 번만 오른다. 접촉 때가 아니라 _ready()에서 거는 이유: 두 몸이
# 같은 프레임에 들어오면 connect가 중복되는지를 따져야 하므로.
func _ready() -> void:
    collected.connect(GameState.collect_fish)


func _on_body_entered(body: Node) -> void:
    if not (body is BabySeal):
        return
    collected.emit()
    queue_free()
