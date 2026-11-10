class_name BabySeal
extends CharacterBody2D

signal landed
# 부활 직후에 나간다. 리스폰은 씬을 리로드하지 않으므로(아래 respawn_at 주석)
# 레벨에 붙어 있던 다른 것들(빙산·HUD)은 부활 사실을 따로 알아야 한다. 죽음의
# 단일 출처는 GameState.player_died 이므로 이 시그널에 죽음 감독자를 붙이지
# 말고, 부활 파생 상태만 여기서 갱신한다.
signal respawned
# 레거시. take_hit()의 마지막 하트에서만 나가고, 즉사(게 밟기·추락·물) 경로는
# 나가지 않는다. 죽음의 단일 출처는 GameState.player_died다: 모든 사망 경로가
# GameState.die()/lose_heart()를 거치므로 흐름(main.gd의 show_game_over)은
# player_died만 구독한다. 이 시그널에 새 구독자를 붙이지 말고, 죽음을 감지해야
# 하면 player_died를 쓴다.
signal died

const GRAVITY := 900.0
const JUMP_VELOCITY := -320.0
const JUMP_CUT := 0.45
const MAX_SPEED := 130.0
const ACCEL := 900.0
const GROUND_FRICTION := 600.0
const AIR_ACCEL_RATIO := 0.6
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12

# 꼬리치기 (설계 5.2). 판정과 쿨다운은 SealSwat이 갖고, 여기서는 시전자가 받는
# 효과만 담당한다.
const SWAT_RECOIL := -150.0
const SWAT_PUSH := 40.0
const SWAT_BRAKE_TIME := 0.15
const SWAT_BRAKE_MULT := 3.0

# Geometry of the throwaway collider used by set_test_floor(). It is placed
# this far below the body origin so its top face lines up with the seal's feet.
const _TEST_FLOOR_THICKNESS := 20.0
const _TEST_FLOOR_WIDTH := 4000.0

# 피격 (설계 5.3). 무적 시간은 GameState가 아니라 시전자가 갖는다: 레벨을
# 리로드하지 않고 인스턴스를 유지하므로, 타이머의 리셋 시점을 여기서 직접
# 제어해야 한다.
const INVULNERABLE_TIME := 1.2
const HURT_KNOCKBACK_X := 180.0
# y+는 아래이므로 위로 띄우려면 음수 (JUMP_VELOCITY와 같은 부호 규칙).
const HURT_KNOCKBACK_Y := -120.0

# 위험 요소 (설계 5.3). 적은 이 그룹에 들어가고, Hurtbox는 그룹으로 적인지
# 판별한다. 그룹 이름은 여기서만 선언한다.
const ENEMY_GROUP := "enemy"

# 추락 사망 (설계 5.3). 구멍이나 물에 빠져 레벨 아래로 내려가면 하트와 무관하게
# 사망한다. 물은 이 조건의 시각적 표현이므로(설계 6.1), 물 자체가 따로 하트를
# 깎지 않고 이 선 아래로 지나가면 죽는다. 화면 높이(360)보다 아래인 420에서
# 끊어서, 카메라에 잠깐 보이다가 죽는 타이밍을 준다.
const FALL_DEATH_Y := 420.0

var facing: int = 1
var is_invulnerable: bool = false

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _jumping: bool = false
var _jump_was_down: bool = false
var _swat_was_down: bool = false
var _was_on_floor: bool = false
var _test_floor: bool = false
var _test_floor_body: StaticBody2D = null
var _swat_brake: float = 0.0
var _invulnerable_timer: float = 0.0
# 이번 프레임의 이동을 만든 수직 속도. body_entered가 발사되는 시점의 velocity.y는
# move_and_slide()이 착지를 처리하며 지우므로, 접촉 판정은 이 값을 쓴다.
var _descending_velocity: float = 0.0


func get_horizontal_speed() -> float:
    return absf(velocity.x)


# 레벨 아래로 떨어진 상태. 이동과 별개로 판정하므로, 이 값으로 죽었는지는
# GameState가 아니라 호출 측이 확인한다.
func is_fallen() -> bool:
    return global_position.y > FALL_DEATH_Y


func is_coyote_active() -> bool:
    return _coyote > 0.0


func is_jump_buffered() -> bool:
    return _jump_buffer > 0.0


# Test-only hook. Production never calls this, so _test_floor stays false there.
# A real StaticBody2D is used rather than faking the flag because
# CharacterBody2D.is_on_floor() reports the physics server's own result and
# cannot be overridden from a script.
func set_test_floor(enabled: bool) -> void:
    if enabled == _test_floor:
        return
    _test_floor = enabled
    if enabled:
        _spawn_test_floor()
    else:
        _despawn_test_floor()


func _spawn_test_floor() -> void:
    var body := StaticBody2D.new()
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(_TEST_FLOOR_WIDTH, _TEST_FLOOR_THICKNESS)
    shape.shape = rect
    body.add_child(shape)

    # The transform has to be set before the node enters the tree: the physics
    # server registers the shape on the first tick, and a transform applied
    # afterwards leaves the shape at the origin for that tick, which shoves the
    # seal sideways on the first frame.
    body.position = global_position + Vector2(0.0, _body_half_height() + _TEST_FLOOR_THICKNESS * 0.5)

    var parent := get_parent()
    if parent == null:
        body.free()
        return
    parent.add_child(body)
    _test_floor_body = body


func _despawn_test_floor() -> void:
    if _test_floor_body != null and is_instance_valid(_test_floor_body):
        _test_floor_body.free()
    _test_floor_body = null


func _body_half_height() -> float:
    for child in get_children():
        var collision := child as CollisionShape2D
        if collision != null and collision.shape is RectangleShape2D:
            return (collision.shape as RectangleShape2D).size.y * 0.5
    return 0.0


func _ready() -> void:
    # 꼬리치기의 넉백 방향은 명중한 대상이 player 그룹에서 시전자를 찾아 구한다
    # (swat_hit(target)은 시전자를 전달하지 않는다).
    add_to_group("player")

    var swat := get_node_or_null("SealSwat") as SealSwat
    if swat != null:
        swat.swat_hit.connect(_on_swat_hit)


func _exit_tree() -> void:
    _despawn_test_floor()


# 꼬리치기 발동. 판정은 SealSwat에 위임하고, 명중한 대상에게서 받는 반동은
# swat_hit 시그널로 들어온다.
func try_swat() -> void:
    var swat := get_node_or_null("SealSwat") as SealSwat
    if swat == null:
        return
    swat.set_direction(facing)
    if not swat.try_swat():
        return
    var anim := get_node_or_null("SealAnim") as SealAnim
    if anim != null:
        anim.play("swat")
    if is_on_floor():
        # 빙판에서 미끄러지는 중에 쓰면 제자리에 딱 멈추는 느낌 (설계 5.2).
        _swat_brake = SWAT_BRAKE_TIME
    else:
        velocity.x += facing * SWAT_PUSH


func _on_swat_hit(target: Node) -> void:
    # y+는 아래이므로 위로 띄우려면 음수. 점프 초속과 같은 부호 규칙.
    velocity.y = SWAT_RECOIL
    # 넉백과 파괴는 대상 자신이 처리한다 (seal_swat.gd 주석). 시그널은 대상만
    # 알려주므로, 대상의 반응을 여기서 호출해 위임한다.
    if target != null and target.has_method("_on_swatted"):
        target.call("_on_swatted")


# 위험 요소 접촉 (설계 5.3). 밟기면 즉사, 측면·후면은 하트 1.
func _on_hurtbox_body_entered(body: Node) -> void:
    # take_hit()은 (body as Node2D).global_position을 읽으므로, Node2D가 아닌
    # 몸이면 여기서 끊는다. 이 검사를 한 번만 하면 _is_stomp()는 다시 가드하지
    # 않아도 된다.
    if not (body is Node2D):
        return
    if not body.is_in_group(ENEMY_GROUP):
        return
    if _is_stomp(body):
        stomp(body)
    else:
        take_hit((body as Node2D).global_position)


# 밟기 판정: 이번 프레임에 아래로 내려오는 중이고, 물범의 발이 적의 중심보다
# 위면 밟기다. y+는 아래이므로 낙하는 양의 수직 속도.
#
# 원점 대신 발로 비교하는 이유: 게 몸체(24px)가 물범(32px)보다 낮다. 평지에서
# 옆으로 부딪혀도 물범의 원점은 이미 게의 원점보다 4px 위에 있으므로, 원점끼리
# 비교하면 측면 충돌이 전부 즉사로 읽힌다.
func _is_stomp(enemy: Node) -> bool:
    if _descending_velocity <= 0.0:
        return false
    return _feet_y() < (enemy as Node2D).global_position.y


func _feet_y() -> float:
    return global_position.y + _body_half_height()


# 게를 밟는 즉사 경로 (설계 5.3). 하트를 한 번에 0으로 만든다.
func stomp(enemy: Node) -> void:
    GameState.die()


# 피격 판정. 무적 중이면 어떤 피격도 통과하지 않는다.
#
# force_left: 넉백 방향을 from_position과의 상대 위치가 아니라 왼쪽으로 고정한다.
# 밀려오는 빙산(소프트 월)은 "밀려오는 쪽"이 정해진 접촉이라, 기본 규칙(피격
# 반대쪽)을 그대로 쓰면 물범을 오른쪽으로 떠밀어 빙산을 따라가게 만든다.
func take_hit(from_position: Vector2, force_left: bool = false) -> void:
    # 이미 죽었다면 추가 피격은 없다. 즉사 경로(게 밟기)가 생겨 "하트 0이면서
    # 무적이 아님"이 레벨 전환 없이도 도달하고, 그 상태의 피격은 lose_heart()를
    # 다시 타서 player_died와 died를 두 번 낸다. 여기서 막으면 어떤 경로로
    # 죽었든 사망 신호는 정확히 한 번이다. 마지막 한 방은 하트가 0이 되기
    # 직전에 도착하므로 이 가드에 막히지 않는다.
    if GameState.is_dead():
        return
    if is_invulnerable:
        return
    is_invulnerable = true
    _invulnerable_timer = INVULNERABLE_TIME
    GameState.lose_heart()
    # 피격음 (설계 11장). 무적·사망 가드를 통과한 "진짜로 한 대 맞은" 프레임에서만
    # 낸다.
    SoundPlayer.play("hurt")

    # y+는 아래이므로 위로 띄우려면 음수. 점프 초속과 같은 부호 규칙.
    var away: float = -1.0 if force_left else signf(global_position.x - from_position.x)
    if away == 0.0:
        away = -1.0
    velocity = Vector2(away * HURT_KNOCKBACK_X, HURT_KNOCKBACK_Y)

    var anim := get_node_or_null("SealAnim") as SealAnim
    if anim != null:
        anim.play("hurt")

    if GameState.is_dead():
        died.emit()


# 체크포인트 부활. 씬을 리로드하지 않고 같은 인스턴스를 제자리로 되돌린다:
# 리로드하면 적이 전부 되살아나는 버그가 생긴다.
func respawn_at(position: Vector2) -> void:
    global_position = position
    velocity = Vector2.ZERO
    is_invulnerable = false
    _invulnerable_timer = 0.0
    GameState.reset_for_level()
    respawned.emit()


func _physics_process(delta: float) -> void:
    var on_floor := is_on_floor()

    if on_floor:
        _coyote = COYOTE_TIME
    else:
        _coyote = maxf(_coyote - delta, 0.0)

    # Input.is_action_just_pressed() is not usable here: it only reports true one
    # physics tick after Input.action_press(), so a press is always missed on the
    # tick it happens. is_action_pressed() flips immediately, so track the press
    # edge on that instead and feed the jump buffer from it.
    var jump_down := Input.is_action_pressed("jump")
    if jump_down and not _jump_was_down:
        _jump_buffer = JUMP_BUFFER
    _jump_was_down = jump_down
    _jump_buffer = maxf(_jump_buffer - delta, 0.0)

    # 꼬리치기 입력 (설계 10장). 점프와 같은 상승 에지 폴링을 쓰는 이유는 위
    # 주석과 같다: is_action_just_pressed() 는 한 물리 틱 늦게 보고해 그 틱의
    # 누름을 놓친다. 여기서 액션을 소비하지 않으면 꼬리치기를 할 수 있는 방법이
    # production 에는 하나도 남지 않는다(레벨 2의 얼음 벽·레벨 3~5의 반동 틈이
    # 진행을 막는다). 판정·쿨다운·애니메이션·제동·밀기는 try_swat() 이 이미
    # 갖고 있으므로 여기서는 누름을 시전으로 바꾸기만 한다.
    var swat_down := Input.is_action_pressed("swat")
    if swat_down and not _swat_was_down:
        try_swat()
    _swat_was_down = swat_down

    if _invulnerable_timer > 0.0:
        _invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
        if _invulnerable_timer <= 0.0:
            is_invulnerable = false

    # Gravity is applied before the jump so a jump started this frame lands on
    # exactly JUMP_VELOCITY instead of one gravity step past it.
    velocity.y += GRAVITY * delta

    if _swat_brake > 0.0:
        _swat_brake = maxf(_swat_brake - delta, 0.0)

    var dir := Input.get_axis("move_left", "move_right")
    if dir != 0.0:
        facing = signi(dir)
        var accel := ACCEL * (AIR_ACCEL_RATIO if not on_floor else 1.0)
        velocity.x = move_toward(velocity.x, dir * MAX_SPEED, accel * delta)
    elif on_floor:
        var friction := GROUND_FRICTION * (SWAT_BRAKE_MULT if _swat_brake > 0.0 else 1.0)
        velocity.x = move_toward(velocity.x, 0.0, friction * delta)

    if is_jump_buffered() and is_coyote_active():
        velocity.y = JUMP_VELOCITY
        _jump_buffer = 0.0
        _coyote = 0.0
        _jumping = true
        # 점프음 (설계 11장). 재생은 SoundPlayer 가, 시점은 점프가 실제로 일어난
        # 이 블록이 정한다 — 버퍼만 찼고 착지가 안 된 프레임에는 소리가 나지
        # 않아야 한다.
        SoundPlayer.play("jump")

    # Variable jump height: releasing early while rising cuts the ascent once.
    if _jumping and velocity.y < 0.0 and not jump_down:
        velocity.y *= JUMP_CUT
        _jumping = false

    if velocity.y >= 0.0:
        _jumping = false

    # 접촉 판정용 낙하 속도. move_and_slide()이 착지한 프레임의 velocity.y를
    # 지우므로, body_entered가 발사되는 시점에는 "떨어지고 있었는가"가 사라진다.
    # 이동을 만든 값을 여기서 따로 보관한다.
    _descending_velocity = velocity.y

    move_and_slide()

    # 추락 사망 (설계 5.3). move_and_slide() 뒤에 검사하는 이유: 이번 프레임의
    # 낙하가 반영된 위치로 판정해야 한 프레임이라도 덜 떨어진다.
    #
    # is_dead() 가드가 필요한 이유: is_fallen()은 y > FALL_DEATH_Y인 한 매 프레임
    # 참이므로, 가드가 없으면 GameState.die()가 프레임마다 다시 불려 player_died가
    # 초당 60회 나간다(Task 12의 show_game_over()가 그만큼 뜬다). take_hit이
    # GameState.is_dead()로 막는 것과 같은 규칙이고, die()의 문서 계약("호출 측이
    # is_dead()로 막는 것을 전제로 한다")도 이 쪽을 전제로 쓴다.
    if is_fallen() and not GameState.is_dead():
        GameState.die()

    var landed_now := is_on_floor()
    if landed_now and not _was_on_floor:
        landed.emit()
    _was_on_floor = landed_now
