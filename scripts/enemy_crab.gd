class_name EnemyCrab
extends CharacterBody2D

# 설계 5.3: 바닥 좌우 순찰만 한다. 추적 AI는 넣지 않는다 — 예측 가능한 패턴이어야
# 플레이어가 "점프로 갈까, 꼬리로 칠까"를 판단하는 재미가 생긴다.

@export var patrol_range: float = 80.0
@export var speed: float = 40.0

var _origin_x: float = 0.0
var _direction: int = 1
# 꼬리치기를 맞으면 순찰을 멈춘다. 그렇지 않으면 이번 프레임의
# _physics_process가 velocity.x를 다시 _direction * speed로 덮어써서, 설계 5.2의
# 넉백(KNOCKBACK 220)이 한 프레임도 살아남지 못한다.
var _swatted: bool = false


func _ready() -> void:
    _origin_x = global_position.x
    # 꼬리치기 판정(SealSwat)과 위험 접촉 판정(BabySeal.Hurtbox)이 그룹으로
    # 대상을 찾는다.
    add_to_group(SealSwat.SWAT_TARGET_GROUP)
    add_to_group(BabySeal.ENEMY_GROUP)


func _physics_process(_delta: float) -> void:
    # 수직 속도를 매 프레임 지운다. 게는 중력이 없으므로 원래 velocity.y 가 0 이어야
    # 하는데, 다른 몸체나 지형에 겹쳐서 물리 서버가 밀어내면 move_and_slide() 이
    # 그 밀어냄을 velocity.y 에 남긴다. 이 값을 지우지 않으면 한 프레임의 밀어냄이
    # 매 프레임 누적돼 적이 레벨 밖으로 영구히 표류한다 (태스크 10 후속 수정:
    # L5 Enemy_5 가 182px 떠오른 뒤 돌아오지 못했다). 중력이 없는 것이 바로 이
    # 값이 리셋되지 않는 이유다.
    velocity.y = 0.0
    if _swatted:
        return
    velocity.x = _direction * speed
    move_and_slide()
    if global_position.x >= _origin_x + patrol_range:
        _direction = -1
    elif global_position.x <= _origin_x - patrol_range:
        _direction = 1


func _on_swatted() -> void:
    _swatted = true
    # 적 제거 소리 (설계 11장). 파괴 판정은 대상 자신이 하므로, 소리도 이쪽에서
    # 낸다. 꼬리치기로 죽은 적과 그 밖의 경로(추락·물)를 구분하지 않는다 —
    # 설계 11장의 "적 제거"는 꼬리치기 경로뿐이다.
    SoundPlayer.play("enemy_down")
    # 설계 5.2: 꼬리치기의 세 효과 중 넉백은 타겟이 자기 속도를 쓴다.
    # SealSwat가 타겟 속도를 쓰면 이 매 프레임 덮어써서 1프레임 만에 지워진다.
    # swat_hit(target)은 시전자를 전달하지 않으므로 player 그룹에서 찾는다.
    var player := get_tree().get_first_node_in_group("player") as Node2D
    var dir := 1.0
    if player != null:
        dir = signi(global_position.x - player.global_position.x)
    velocity.x = dir * SealSwat.KNOCKBACK
    queue_free()
