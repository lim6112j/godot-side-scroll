extends RefCounted

# 작업 9: 위험 요소 — 얇은 얼음, 고드름, 물, 깨지는 얼음 블록.
#
# 설계 5.3의 규칙을 그대로 검사한다.
# - 얇은 얼음: 밟으면 0.3초 후 깨진다. 금 간 표면으로 예고한다.
# - 고드름: 매달려 있다가 플레이어가 아래로 지나가면 낙하하고, 맞으면 하트가 준다.
# - 물 (빙하 틈): 닿으면 즉사.
# - 깨지는 얼음 블록: 꼬리치기로 파괴.
# - 레벨 아래로 추락하면 사망 (BabySeal.FALL_DEATH_Y).
#
# y+는 아래다. 낙하는 양의 velocity.y.

# 물리 프레임 1개 = 1/60초. 얇은 얼음의 collapse_delay는 0.3초(18프레임).
# 12프레임(0.20초) 지점에서는 반드시 살아 있어야 한다. 겹침이 한 프레임 늦게
# 잡혀도 타이머 시작이 밀리므로 살아남는다.
const THIN_ICE_ALIVE_FRAMES := 12
# 0.30초가 지난 뒤에는 깨져 있어야 한다. 겹침 등록이 늦어지는 만큼 여유를 두되,
# 0.5초를 넘기면 delay가 0.3초라는 설계 값을 지키지 않는 것이므로 상한으로 쓴다.
const THIN_ICE_COLLAPSE_LIMIT := 30

# 고드름 낙하 속도 260px/s. 10프레임(0.167초)이면 43px 내려오므로, 5px 기준선은
# 넘는다. 아직 낙하하지 않았으면 0px이므로 기준선이 둘을 구분한다.
const ICICLE_FALL_FRAMES := 10

# 꼬리치기 판정은 Area2D가 물리 서버에 등록된 뒤 한 프레임 뒤에 나온다
# (test_enemies.gd의 SWAT_SETTLE_FRAMES와 같은 이유). 등록 지연을 흡수하도록
# 상한을 둔다.
const SWAT_BREAK_LIMIT := 6

# 물에 닿아 사망했는지 확인할 프레임. 물판은 64px 두껲이고 물범은 400px/s로
# 떨어지므로 4프레임이면 확실히 겹친다.
const WATER_FALL_FRAMES := 4

# 추락 판정 아래에서 머무는 프레임. is_fallen()은 이 구간 내내 참이므로,
# is_dead() 가드가 없으면 GameState.die()가 이 프레임 수만큼 다시 불린다.
const FALL_SIGNAL_FRAMES := 10

# 물범이 아닌 물리 바디(게)로 위험 요소의 음성 분기를 확인할 프레임. 얇은 얼음은
# collapse_delay 0.3초(18프레임)이므로 12프레임은 "아직 살아 있어야 하는" 구간이다.
const GUARD_FRAMES := 12


func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # The runner awaits run() from inside _ready(), so the tree is still busy
    # propagating ready notifications here and add_child() would be rejected.
    # Yield one physics frame first so the seal actually enters the tree.
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    # ── 얇은 얼음: 밟으면 0.3초 후 무너짐 (설계 5.3) ──
    GameState.reset_for_level()
    var thin := preload("res://scenes/entities/hazard_thin_ice.tscn").instantiate() as Area2D
    thin.global_position = Vector2(0, 0)
    var collapsed := [false]
    # 시그널 연결은 add_child 전에 끝낸다. delay가 0이면(돌연변이) 얇은 얼음은
    # 첫 프레임에 무너지고 그 프레임 말에 해제되는데, 그 뒤에 연결하려고 하면
    # "previously freed" 스크립트 오류로 스위트가 통째로 죽어서 체크가 0개가
    # 된다. 그러면 돌연변이가 실패로 잡히지 않고 조용히 통과한다(탐측 확인).
    thin.collapsed.connect(func() -> void: collapsed[0] = true)
    await t.step_frames(tree, 1)
    tree.root.add_child(thin)
    await t.step_frames(tree, 2)
    # 형태 오프셋과 무관하게 겹치게 같은 좌표에 둔다.
    seal.global_position = Vector2(0, 0)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, THIN_ICE_ALIVE_FRAMES)
    t.check(not collapsed[0], "0.20초 후에도 아직 무너지지 않았다")
    # 0.30초가 지나면 무너진다. 프레임 단위로 폴링한다: 무너지는 정확한 프레임은
    # 겹침이 등록되는 시점에 좌우되고, 그 다음 프레임에는 이미 노드가 해제되어
    # 프로퍼티를 읽을 수 없다(탐측 확인). 폴링으로 그 프레임을 놓치지 않는다.
    var extra := 0
    while not collapsed[0] and extra < THIN_ICE_COLLAPSE_LIMIT:
        await t.step_frames(tree, 1)
        extra += 1
    t.check(collapsed[0], "0.30초 후 무너진다")
    # 제거 증거. queue_free()는 시그널 이후에 호출되고, 실제 해제는 프레임 말
    # 플러시에서 일어나므로, 테스트가 다시 도는 시점에는 노드가 이미 없다.
    # 그래서 "큐에 들어갔는지"가 아니라 "트리에서 사라졌는지"로 확인한다.
    await t.step_frames(tree, 1)
    t.check(not is_instance_valid(thin), "무너진 얇은 얼음이 제거된다")

    # ── 물: 닿으면 사망 (설계 5.3) ──
    GameState.reset_for_level()
    var water := preload("res://scenes/entities/hazard_water.tscn").instantiate() as Area2D
    water.global_position = Vector2(0, 200)
    await t.step_frames(tree, 1)
    tree.root.add_child(water)
    await t.step_frames(tree, 2)
    # 물범을 물판 위에 두고 떨어뜨린다. y+는 아래이므로 낙하는 양의 velocity.y.
    seal.global_position = Vector2(0, 180)
    seal.velocity = Vector2(0, 400)
    await t.step_frames(tree, WATER_FALL_FRAMES)
    t.check(GameState.is_dead(), "물에 닿으면 사망한다")

    # ── 고드름: 플레이어가 지나가면 낙하한다 (설계 5.3) ──
    GameState.reset_for_level()
    var icicle := preload("res://scenes/entities/hazard_icicle.tscn").instantiate() as Area2D
    await t.step_frames(tree, 1)
    tree.root.add_child(icicle)
    await t.step_frames(tree, 2)
    # 낙하 속도 자체를 고정한다. 아래 "5px 이상 내려왔는가"만으로는 260이 60으로
    # 줄어도(10프레임에 10px) 통과해 버려 값이 의미를 잃는다.
    t.approx(icicle.fall_speed, 260.0, 0.01, "고드름 낙하 속도 260")
    icicle.global_position = Vector2(0, -30)
    seal.global_position = Vector2(0, 0)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)
    var y0: float = icicle.global_position.y
    await t.step_frames(tree, ICICLE_FALL_FRAMES)
    t.check(icicle.global_position.y > y0 + 5.0, "플레이어가 지나가면 고드름이 낙하한다")

    # ── 고드름에 맞으면 피격 (설계 5.3) ──
    # 윗 단계의 take_hit이 1.2초 무적을 남겨둔다. respawn_at()은 하트를
    # reset_for_level()으로 복원하고 무적도 함께 지우므로, 이 검사 전에 호출한다.
    seal.respawn_at(Vector2(0, 0))
    t.check(GameState.hearts == 3, "피격 전 하트 3")
    # 형태 오프셋과 무관하게 겹치게 같은 좌표에 둔다.
    icicle.global_position = seal.global_position
    await t.step_frames(tree, 6)
    t.check(GameState.hearts < 3, "고드름에 맞으면 하트가 준다")

    # ── 깨지는 얼음 블록: 꼬리치기로 파괴 (설계 5.3) ──
    GameState.reset_for_level()
    var block := preload("res://scenes/entities/hazard_ice_block.tscn").instantiate() as StaticBody2D
    block.global_position = Vector2(300, 0)
    await t.step_frames(tree, 1)
    tree.root.add_child(block)
    await t.step_frames(tree, 2)
    var swat := seal.get_node("SealSwat") as SealSwat
    # 꼬리치기 판정 사거리: 판정 영역 중심이 전방 REACH*0.5(22px)에 있고 폭이
    # 44px이므로, 물범에서 22~44px 앞을 친다. 40px 앞에 두면 블록에 닿는다.
    seal.global_position = Vector2(260, 0)
    seal.velocity = Vector2.ZERO
    swat.try_swat()
    var waited := 0
    while is_instance_valid(block) and waited < SWAT_BREAK_LIMIT:
        await t.step_frames(tree, 1)
        waited += 1
    # 제거 증거. 꼬리치기 맞은 대상은 queue_free()로 사라지고, 해제는 프레임 말
    # 플러시에서 일어나므로 여기서는 인스턴스가 유효하지 않다.
    t.check(not is_instance_valid(block), "꼬리치기로 얼음 블록이 파괴된다")

    # ── 레벨 아래로 추락하면 사망 (설계 5.3) ──
    # 사망 신호도 정확히 한 번. is_fallen()은 y > FALL_DEATH_Y인 한 매 프레임
    # 참이므로, is_dead() 가드가 없으면 GameState.die()가 프레임마다 다시 불려
    # player_died가 초당 60회 나간다(Task 12의 show_game_over()가 그만큼 뜬다).
    # take_hit이 GameState.is_dead()로 막는 것과 한 규칙이다.
    GameState.reset_for_level()
    var fall_deaths := [0]
    var on_player_died := func() -> void: fall_deaths[0] += 1
    GameState.player_died.connect(on_player_died)
    seal.global_position = Vector2(0, BabySeal.FALL_DEATH_Y + 50)
    await t.step_frames(tree, FALL_SIGNAL_FRAMES)
    t.check(GameState.is_dead(), "레벨 아래로 떨어지면 사망한다")
    t.check(fall_deaths[0] == 1, "추락 사망 신호는 정확히 한 번 나간다")
    GameState.player_died.disconnect(on_player_died)

    # ── 물범이 아닌 물체는 위험 요소를 건드리지 않는다 (BabySeal 가드) ──
    # 먼저 물범을 추락선 위로 되돌린다. y > FALL_DEATH_Y인 채로
    # reset_for_level()을 부르면, 다음 프레임의 _physics_process이 다시
    # GameState.die()를 불러 이 구간의 전 검사가 "이미 죽음"을 보게 된다(탐측 확인).
    seal.global_position = Vector2(0, 0)
    seal.velocity = Vector2.ZERO
    await t.step_frames(tree, 2)
    GameState.reset_for_level()
    var guard_crabs: Array = []
    var guard_crab: CharacterBody2D = null

    # 물: 게가 물판 한가운데로 떨어져도 죽지 않는다.
    guard_crab = await _add_nonseal_body(t, tree, Vector2(400, 200))
    guard_crabs.append(guard_crab)
    var water_guard := preload("res://scenes/entities/hazard_water.tscn").instantiate() as Area2D
    var water_guard_hits := [0]
    water_guard.body_entered.connect(func(_b: Node) -> void: water_guard_hits[0] += 1)
    water_guard.global_position = Vector2(400, 200)
    await t.step_frames(tree, 1)
    tree.root.add_child(water_guard)
    await t.step_frames(tree, WATER_FALL_FRAMES)
    t.check(water_guard_hits[0] > 0, "물판이 물범이 아닌 물체와의 겹침을 감지한다")
    t.check(not GameState.is_dead(), "물범이 아닌 물체는 물로 죽지 않는다")

    # 고드름: 게가 아래로 지나가도 낙하하지 않는다.
    guard_crab = await _add_nonseal_body(t, tree, Vector2(400, 0))
    guard_crabs.append(guard_crab)
    var icicle_guard := preload("res://scenes/entities/hazard_icicle.tscn").instantiate() as Area2D
    var icicle_guard_hits := [0]
    icicle_guard.body_entered.connect(func(_b: Node) -> void: icicle_guard_hits[0] += 1)
    icicle_guard.global_position = Vector2(400, -30)
    await t.step_frames(tree, 1)
    tree.root.add_child(icicle_guard)
    await t.step_frames(tree, 2)
    var y_guard: float = icicle_guard.global_position.y
    await t.step_frames(tree, ICICLE_FALL_FRAMES)
    t.check(icicle_guard_hits[0] > 0, "고드름이 물범이 아닌 물체와의 겹침을 감지한다")
    t.check(icicle_guard.global_position.y <= y_guard + 5.0, "물범이 아닌 물체는 고드름을 떨어뜨리지 않는다")

    # 얇은 얼음: 게가 밟아도 무너지지 않는다.
    guard_crab = await _add_nonseal_body(t, tree, Vector2(400, 0))
    guard_crabs.append(guard_crab)
    var thin_guard := preload("res://scenes/entities/hazard_thin_ice.tscn").instantiate() as Area2D
    var thin_guard_hits := [0]
    thin_guard.body_entered.connect(func(_b: Node) -> void: thin_guard_hits[0] += 1)
    var thin_guard_collapsed := [false]
    thin_guard.collapsed.connect(func() -> void: thin_guard_collapsed[0] = true)
    thin_guard.global_position = Vector2(400, 0)
    await t.step_frames(tree, 1)
    tree.root.add_child(thin_guard)
    await t.step_frames(tree, GUARD_FRAMES)
    t.check(thin_guard_hits[0] > 0, "얇은 얼음이 물범이 아닌 물체와의 겹침을 감지한다")
    t.check(not thin_guard_collapsed[0], "물범이 아닌 물체는 얇은 얼음을 무너뜨리지 않는다")

    # 정리 전에 물범을 안전한 높이로 되돌린다. FALL_DEATH_Y 아래에 남겨 두면
    # queue_free()가 프레임 말까지 늦어지는 동안 이 물범의 _physics_process가
    # GameState.die()를 또 호출해서, 뒤따라 도는 스위트(health)가 reset_for_level()
    # 직후 하트 0 상태를 보게 된다(탐측 확인). 위치만 되돌리면 그 프레임에는
    # 죽지 않는다.
    seal.global_position = Vector2(0, 0)
    for n in [thin, water, icicle, block, seal, water_guard, icicle_guard, thin_guard] + guard_crabs:
        if is_instance_valid(n):
            n.queue_free()


# 물범이 아닌 물리 바디(게)를 놓고 트리에 넣는다. 게는 물판·고드름·얇은 얼음과
# 같은 기본 물리 레이어에 있으므로, 겹침은 정상적으로 잡힌다 — 각 위험 요소의
# `body is BabySeal` 가드가 반응을 막는지 확인하는 데 쓴다.
func _add_nonseal_body(t: TestHelper, tree: SceneTree, at: Vector2) -> CharacterBody2D:
    var crab := preload("res://scenes/entities/enemy_crab.tscn").instantiate() as CharacterBody2D
    crab.global_position = at
    await t.step_frames(tree, 1)
    tree.root.add_child(crab)
    await t.step_frames(tree, 2)
    return crab
