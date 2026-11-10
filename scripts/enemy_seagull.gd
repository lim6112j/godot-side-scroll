class_name EnemySeagull
extends CharacterBody2D

# 설계 5.3: 좌우 직선 비행만 한다. 플레이어를 추격하지 않는다.
# 갈매기는 점프로 회피하거나 꼬리치기로 제거한다.

@export var flight_range: float = 200.0
@export var speed: float = 90.0

var _origin_x: float = 0.0
var _direction: int = -1   # 왼쪽으로 날아온다
# 꼬리치기를 맞으면 비행을 멈춘다. 그렇지 않으면 이번 프레임의 _physics_process가
# velocity.x를 다시 덮어써서, 설계 5.2의 넉백(KNOCKBACK 220)이 한 프레임도
# 살아남지 못한다.
var _swatted: bool = false


func _ready() -> void:
    _origin_x = global_position.x
    # 꼬리치기 판정(SealSwat)과 위험 접촉 판정(BabySeal.Hurtbox)이 그룹으로
    # 대상을 찾는다.
    add_to_group(SealSwat.SWAT_TARGET_GROUP)
    add_to_group(BabySeal.ENEMY_GROUP)


func _physics_process(_delta: float) -> void:
    # 수직 속도를 매 프레임 지운다. 갈매기는 중력이 없으므로 원래 velocity.y 가 0
    # 이어야 하는데, 다른 몸체나 지형에 겹쳐서 물리 서버가 밀어내면 move_and_slide()
    # 이 그 밀어냄을 velocity.y 에 남긴다. 이 값을 지우지 않으면 한 프레임의
    # 밀어냄이 매 프레임 누적돼 적이 레벨 밖으로 영구히 표류한다 (태스크 10 후속
    # 수정: L5 Enemy_5 가 182px 떠오른 뒤 돌아오지 못했다). 중력이 없는 것이 바로
    # 이 값이 리셋되지 않는 이유다.
    velocity.y = 0.0
    if _swatted:
        return
    velocity.x = _direction * speed
    move_and_slide()
    if global_position.x <= _origin_x - flight_range:
        _direction = 1
    elif global_position.x >= _origin_x + flight_range:
        _direction = -1


func _on_swatted() -> void:
    _swatted = true
    # 적 제거 소리 (설계 11장). 게와 같은 규칙 — 꼬리치기로 제거된 적이 낸다.
    SoundPlayer.play("enemy_down")
    # 게와 동일: 넉백은 타겟이 자기 속도를 쓴다.
    var player := get_tree().get_first_node_in_group("player") as Node2D
    var dir := 1.0
    if player != null:
        dir = signi(global_position.x - player.global_position.x)
    velocity.x = dir * SealSwat.KNOCKBACK
    queue_free()
