class_name IceBlock
extends StaticBody2D

# 깨지는 얼음 블록 (설계 5.3 / 5.8 장치 A). 점프 상승(약 57px)으로는 넘을 수
# 없는 높이(90~110px)의 벽을 세워서 꼬리치기를 강제한다. 파괴는 대상 자신이
# 처리한다 (seal_swat.gd 주석): SealSwat은 swat_hit 시그널로 알려주기만 하고,
# 넉백과 파괴는 대상이 자기 것으로 적용한다.
#
# StaticBody2D인 이유: 길을 막는 장애물이자 발판이다. 꼬리치기로 없어지기
# 전까지는 물리 지면으로 서 있어야 한다.

func _on_swatted() -> void:
    queue_free()
