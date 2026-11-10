class_name MomSeal
extends Node2D

# 엄마 물범 (설계 5.4 / 7.4). 각 레벨 오른쪽 끝의 빙하 위에 가만히 서 있다가,
# 아기 물범이 도착하면 지느러미를 흔든다.
#
# CharacterBody2D가 아닌 Node2D인 이유: 설계 7.4 그대로다. 움직이지 않고
# 지느러미만 흔드므로 물리가 필요 없다.
#
# 퍼펫 교체 규칙(태스크 3)을 지키려고 애니메이션 트랙은 피벗 프로퍼티만
# 겨냥한다. 시각 슬롯이나 도형 파츠는 건드리지 않는다.

@onready var _anim: AnimationPlayer = $AnimationPlayer


# 도착 연출. wave는 원샷이라 끝나면 마지막 키 값(지느러미가 살짝 올라간 자세)을
# 유지한다 — 다시 idle로 되돌리면 "흔든 뒤 가만히 있다"는 느낌이 죽는다.
func celebrate() -> void:
    _anim.play("wave")
