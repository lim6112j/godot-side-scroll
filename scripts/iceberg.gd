class_name Iceberg
extends Area2D

# 밀려오는 빙산 (레벨 5 시간 압박). 레벨 시작점 뒤쪽에서 나타나 오른쪽으로 이동한다.
#
# 소프트 월인 이유: 물리 충돌이 없으므로 레벨을 막지 않는다. 닿으면 즉사가 아니라
# 하트 1 + 왼쪽 넉백이라, 빙산이 레벨을 클리어 불가능하게 만들 수 없다 (설계 전제:
# "압박이지 벽이 아니다").
#
# 좌표 규칙: y+는 아래(Engine rule 2). 노드 원점은 빙산의 중심이고, 생성기가
# 지면 표면(y=0) 위에 세우므로 반높이만큼 올린 자리에 둔다.

@export var speed: float = 40.0

# 부활 시 플레이어 뒤로 물러나는 거리. 부활 지점에 빙산이 그대로 남아 있으면
# 닿자마자 하트가 깎여 죽음이 무한 반복하므로, 이 거리만큼 뒤로 보낸다.
const REPOSITION_OFFSET := 400.0


# 소프트 월 표시. 즉사 판정을 하는 쪽이 "이것은 죽음이 아니다"를 확인하게 한다.
func is_soft_wall() -> bool:
	return true


# 플레이어를 x 뒤쪽으로 재배치한다. 부활 직후의 캠핑을 끊는 용도.
func reposition_behind(x: float) -> void:
	global_position.x = x - REPOSITION_OFFSET


func _physics_process(delta: float) -> void:
	global_position.x += speed * delta


# 소프트 월 접촉. 하트와 넉백, 무적은 BabySeal.take_hit() 이 이미 갖고 있으므로
# 그 경로를 그대로 탄다: 여기서 하트를 직접 깎으면 물범의 1.2초 무적과 사망
# 신호(한 번만 나가는 규칙)를 건너뛰어 재접촉이 무한 루프가 된다.
func _on_body_entered(body: Node) -> void:
	var seal := body as BabySeal
	if seal == null:
		return
	# 빙산은 "밀려오는 쪽"이 정해진 접촉이라 넉백 방향을 위치가 아니라 왼쪽으로
	# 고정한다. take_hit()의 기본 규칙(피격 반대쪽)을 쓰면 물범을 오른쪽으로
	# 떠밀어 빙산을 따라가게 만든다.
	seal.take_hit(global_position, true)
