class_name SealSwat
extends Node2D

# 꼬리치기 판정 (설계 5.2). 판정 영역의 활성 주기와 쿨다운은 이 노드가 갖고,
# 명중한 대상이 받을 효과는 swat_hit 시그널로만 알린다. 반동은 BabySeal이,
# 넉백과 파괴는 대상 자신이 처리한다.
#
# Node2D여야 한다. 판정 영역(SwatHitbox Area2D)의 위치는 이 노드를 기준으로
# 상대적으로 배치되는데, Node를 쓰면 CanvasItem 조상이 없어져서 Area2D의
# global_position이 뷰포트 원점 기준으로 고정된다. 그러면 물범이 어디로
# 움직이든 판정 영역은 세계 좌표 (-22, 0)에 그대로 남아, 적을 실제로 칠 수
# 없다 (탐측으로 확인).
signal swat_hit(target: Node)

const SWAT_TARGET_GROUP := "swat_target"

const DURATION := 0.15
const COOLDOWN := 0.40

# 넉백은 명중한 대상이 스스로 적용한다. SealSwat은 swat_hit만 알리고,
# 220px/s 값을 여기서 보관한다 (설계 5.2).
const KNOCKBACK := 220.0

# 판정 영역: 정면 부채를 직사각형으로 근사한다. 가로 44px가 씬의 shape 크기이고,
# REACH는 그 중심을 전방으로 밀어내는 오프셋이다.
const REACH := 44.0

var _active: float = 0.0
var _cooldown: float = 0.0
var _direction: int = 1
var _hit_targets: Array[Node] = []

@onready var _hitbox: Area2D = $SwatHitbox


func try_swat() -> bool:
    if _cooldown > 0.0:
        return false
    _active = DURATION
    _cooldown = COOLDOWN
    _hitbox.monitoring = true
    # 꼬리치기 소리 (설계 11장). "성공한 시도"에서만 나야 하므로, 쿨다운에
    # 막힌 호출이 아니라 활성화가 실제로 일어난 이 블록에서 낸다.
    SoundPlayer.play("swat")
    return true


func is_active() -> bool:
    return _active > 0.0


func is_on_cooldown() -> bool:
    return _cooldown > 0.0


func get_hitbox() -> Area2D:
    return _hitbox


# 판정 영역은 보이지 않지만 전방을 향해야 하므로, BabySeal이 매 프레임 방향을 밀어넣는다.
func set_direction(direction: int) -> void:
    _direction = -1 if direction < 0 else 1


func _physics_process(delta: float) -> void:
    _hitbox.position = Vector2(_direction * REACH * 0.5, 0.0)

    if _active > 0.0:
        _active = maxf(_active - delta, 0.0)
        if _active <= 0.0:
            _hitbox.monitoring = false
            _hit_targets.clear()
    if _cooldown > 0.0:
        _cooldown = maxf(_cooldown - delta, 0.0)


func _on_body_entered(body: Node) -> void:
    if not is_active():
        return
    if not body.is_in_group(SWAT_TARGET_GROUP):
        return
    # 같은 시전에서 한 대상은 한 번만 친다.
    if _hit_targets.has(body):
        return
    _hit_targets.append(body)
    swat_hit.emit(body)
