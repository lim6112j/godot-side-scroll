extends RefCounted

# 태스크 13: 밀려오는 빙산 (레벨 5).
#
# 설계: 시간 압박(has_time_pressure)이 있는 레벨에만 시작점 뒤쪽에서 오른쪽으로
# 밀려오는 빙산이 있다. 빙산은 소프트 월이라 즉사가 아니라 하트 1 + 왼쪽 넉백이므로
# 레벨을 클리어 불가능하게 만들지 않는다. 부활 때 물범 뒤로 재배치해 부활 지점
# 캠핑(닿자마자 죽음이 무한 반복)을 끊는다.
#
# 함께 Task 12 리뷰에서 이 태스크로 넘어온 항목을 같은 흐름 위에서 확인한다:
#   - 완료 화면 버튼 레이블 (tests/test_flow.gd 의 레이블 표)
#   - 부활 후 HUD 물고기 카운터 재시드 (reset_for_level 은 fish_changed 를 내지 않는다)
#   - 레벨 상태의 단일 소유자는 Level.setup() (Main 은 reset 하지 않는다)
#
# Task 14에서는 이 파일의 마지막에 사망 경로를 추가한다: 리뷰에서 respawn_at()의
# 생산 호출이 0개임이 확인되어 빙산 재배치가 죽은 코드였으므로, 사망 신호에서
# 체크포인트 부활을 탔을 때 재배치가 실제로 도는지를 본다.
#
# y+는 아래다.

# hearts_changed 발신 횟수를 세기 위한 카운터. 람다 대신 메서드를 쓰는 이유:
# GDScript 람다가 잡는 변수는 복사라 카운트가 밖으로 새지 않는다.
var _heart_beats: int = 0
# player_died 발신 횟수. 연속 접촉이 무한 루프를 만들면 이 값이 1을 넘는다.
var _death_beats: int = 0


func _count_heart_beat(_value: int) -> void:
	_heart_beats += 1


func _count_death_beat() -> void:
	_death_beats += 1


func run(t: TestHelper) -> void:
	var tree := Engine.get_main_loop() as SceneTree

	# 시간 압박이 없는 레벨에는 빙산이 없다
	var gen := LevelGenerator.new()
	var r1: Dictionary = gen.generate(LevelRegistry.get_level(1) as LevelData)
	var l1 := r1["root"] as Node2D
	t.check(l1.find_child("Iceberg", true, false) == null, "레벨 1에 빙산이 없다")
	l1.free()

	# 오직 레벨 5 에만 시간 압박이 있으므로 2~4 에도 빙산이 없다. 이 검사가 없으면
	# 다른 레벨에 빙산이 붙어도 통과한다.
	var others_clean := true
	for i in [2, 3, 4]:
		var res: Dictionary = gen.generate(LevelRegistry.get_level(i) as LevelData)
		var lv := res["root"] as Node2D
		if lv.find_child("Iceberg", true, false) != null:
			others_clean = false
		lv.free()
	t.check(others_clean, "레벨 2~4 에 빙산이 없다")

	# 레벨 5에는 빙산이 있다
	var r5: Dictionary = gen.generate(LevelRegistry.get_level(5) as LevelData)
	var l5 := r5["root"] as Node2D
	var berg := l5.find_child("Iceberg", true, false) as Iceberg
	t.check(berg != null, "레벨 5에 빙산이 있다")
	if berg == null:
		return

	# 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
	# 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로, 한 프레임 먼저
	# yield 한다 (태스크 2 엔진 트랩 1).
	await t.step_frames(tree, 1)
	tree.root.add_child(l5)
	await t.step_frames(tree, 2)
	t.check(berg.is_soft_wall(), "빙산은 소프트 월이다 (즉사 아님)")

	var x0: float = berg.global_position.x
	await t.step_frames(tree, 30)
	t.check(berg.global_position.x > x0, "빙산이 오른쪽으로 이동한다")

	# 접촉 시 하트 1 감소, 즉사 아님
	GameState.reset_for_level()
	var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
	tree.root.add_child(seal)
	await t.step_frames(tree, 2)
	seal.global_position = berg.global_position + Vector2(0, -20)
	await t.step_frames(tree, 3)
	t.check(GameState.hearts == 2, "빙산 접촉 시 하트가 1 준다")
	t.check(not GameState.is_dead(), "빙산 접촉으로 즉사하지 않는다")
	# 밀려오는 쪽(왼쪽)으로 밀려야 한다: 오른쪽으로 밀면 빙산이 물범을 떠민다.
	t.check(seal.velocity.x < 0.0, "빙산 접촉 시 물범이 왼쪽으로 밀린다")

	# 부활 시 빙산이 플레이어 뒤로 재배치된다
	GameState.reset_for_level()
	var respawn_at := Vector2(2000, 100)
	seal.respawn_at(respawn_at)
	berg.reposition_behind(respawn_at.x)
	t.check(berg.global_position.x < respawn_at.x - 200.0,
		"부활 시 빙산이 플레이어 뒤 200px 이상에 있다")
	await t.step_frames(tree, 5)
	t.check(not GameState.is_dead(), "부활 직후 빙산이 플레이어를 덮치지 않는다")

	# 연속 접촉이 무한 루프를 만들지 않는다.
	#
	# 브리프 원안은 배치 간격을 3 프레임으로 뒀다. 그 값으로는 첫 접촉의 무적
	# (1.2 초 = 72 프레임)이 끝나기 전에 다음 배치가 들어가므로 뒤의 배치가 전부
	# 노옵이고 하트는 하나만 줄어, 아래 두 검사가 언제나 통과해 아무것도 잠그지
	# 못했다:
	#   hearts >= 0                — lose_heart() 의 maxi(0, …) 클램프가 이미 보장
	#   hearts > 0 or is_dead()    — is_dead() 가 hearts <= 0 이므로 항상 참
	# 간격을 120 프레임(2 초)으로 늘려 각 배치가 실제로 한 번씩 히트하게 만든다.
	#
	# 이 검사가 빙산 접촉 때문에 통과하려면 두 가지를 더 해야 한다:
	#  - 배치할 때마다 영역 밖으로 뺐다가 넣는다. Area2D 의 body_entered 는
	#    "들어온 순간"에만 나므로, 안에 붙어 있으면 재배치해도 다시 나지 않는다.
	#  - 테스트 지면을 깐다. 120 프레임을 기다리면 물범이 y=420 아래로 떨어져
	#    추락 사망이 끼어, 하트가 0 이 되는 이유가 빙산이 아니라 낙하가 된다.
	seal.global_position = berg.global_position + Vector2(0, -20)
	seal.set_test_floor(true)
	await t.step_frames(tree, 2)
	GameState.reset_for_level()
	_death_beats = 0
	GameState.player_died.connect(_count_death_beat)
	for i in 5:
		seal.global_position = berg.global_position + Vector2(1000, -20)
		await t.step_frames(tree, 2)
		seal.global_position = berg.global_position + Vector2(0, -20)
		await t.step_frames(tree, 120)
	GameState.player_died.disconnect(_count_death_beat)
	t.check(GameState.hearts == 0, "연속 접촉이 무적 창을 넘어 하트를 모두 소진한다")
	t.check(GameState.is_dead(), "연속 접촉으로 사망 상태에 도달한다")
	t.check(_death_beats == 1, "연속 접촉에서 player_died 가 한 번만 나간다")

	# 생성기만으로 확인한 것은 실제 조립 경로(Main)와 다르므로, 여기서부터는
	# Main 이 레벨을 조립한 상태에서 부활 배선을 본다.
	#
	# 테스트 지면은 queue_free() 전에 직접 걷는다. _exit_tree() 안에서
	# _despawn_test_floor() 가 body.free() 를 부르면 트리가 자식 정리 중이라
	# remove_child() 가 거부되어 exit code 134(SIGABRT) 로 죽는다 (test_movement·
	# test_swat 도 같은 이유로 명시적으로 걷는다).
	seal.set_test_floor(false)
	seal.queue_free()
	l5.queue_free()
	await t.step_frames(tree, 2)

	var main := preload("res://scenes/main.tscn").instantiate() as Node
	await t.step_frames(tree, 1)
	tree.root.add_child(main)
	await t.step_frames(tree, 2)

	# 레벨 상태의 단일 소유자는 Level.setup() 이다. Main 이 먼저
	# reset_for_level() 을 부르면 곧 떼어 낼 HUD 에게 hearts_changed 가 한 번 더
	# 나가므로, 레벨 로드 중 발신 횟수가 정확히 1 이어야 한다.
	_heart_beats = 0
	GameState.hearts_changed.connect(_count_heart_beat)
	main.call("goto_level", 5)
	GameState.hearts_changed.disconnect(_count_heart_beat)
	t.check(_heart_beats == 1, "레벨 로드 중 hearts_changed 가 한 번만 나간다")

	await t.step_frames(tree, 3)
	var seal2 := main.find_child("BabySeal", true, false) as BabySeal
	var berg2 := main.find_child("Iceberg", true, false) as Iceberg
	var hud := main.find_child("Hud", true, false) as Hud

	# 빙산이 물범을 앞지른 상태(캠핑 위험 상태)를 만든 뒤 부활시킨다. 부활점보다
	# 오른쪽에 두는 이유: 재배치가 빠지면 이 검사가 그대로 통과해버리기 때문이다
	# (뮤테이션 (b)에서 실제로 빠졌음을 확인했다).
	if seal2 != null and berg2 != null:
		berg2.global_position = Vector2(respawn_at.x + 200.0, berg2.global_position.y)
	# 먹은 물고기를 HUD 에 반영해 "물고기 2 / total" 상태로 만든다.
	GameState.collect_fish()
	GameState.collect_fish()
	await t.step_frames(tree, 2)
	if seal2 != null:
		seal2.respawn_at(respawn_at)
	await t.step_frames(tree, 2)

	t.check(berg2 != null and berg2.global_position.x < respawn_at.x - 200.0,
		"Main 이 부활 시 빙산을 물범 뒤로 재배치한다")
	var fish_label := hud.get_node("FishLabel") as Label if hud != null else null
	t.check(fish_label != null and fish_label.text == "물고기 0 / %d" % GameState.fish_total,
		"부활 후 HUD 물고기 카운터가 0 / 총계로 다시 시드된다")

	# ── 사망 경로에서 체크포인트 부활이 실제로 도는지 (태스크 14) ──
	# 태스크 13 리뷰에서 넘어온 항목: respawn_at()에 생산 호출이 하나도 없어서
	# 위 재배치(reposition_behind)는 배송된 게임에서 죽은 코드였다. 여기서는
	# 사망 신호를 실제로 내서 — respawn_at()을 직접 부르지 않고 — 물범이 마지막으로
	# 통과한 체크포인트로 부활하고, 그 부활이 빙산 재배치를 trig 하는지를 본다.
	var seal3 := main.find_child("BabySeal", true, false) as BabySeal
	var berg3 := main.find_child("Iceberg", true, false) as Iceberg
	var gen5b := LevelGenerator.new()
	var res5b: Dictionary = gen5b.generate(LevelRegistry.get_level(5) as LevelData)
	var cps5: Array = res5b["checkpoints"] as Array
	var cp5: Vector2 = (cps5[0] as Vector2) if cps5.size() > 0 else Vector2.ZERO
	res5b["root"].free()
	if seal3 != null and cp5 != Vector2.ZERO:
		seal3.global_position = cp5
	# 빙산을 물범보다 오른쪽에 둔다. 재배치가 빠지면 아래 검사가 그대로 통과해버리기
	# 때문이다 (위 Main 항목과 같은 이유).
	if berg3 != null:
		berg3.global_position = Vector2(cp5.x + 200.0, berg3.global_position.y)
	await t.step_frames(tree, 2)
	GameState.die()
	# 위치는 사망 신호 직후에 비교한다. 물범을 체크포인트로 옮기면 그 자리에 서 있던
	# 적에게 닿아 넉백이 붙으므로(체크포인트는 적 회피를 모른다) 프레임을 흘리면 좌표가
	# 흔들린다. 부활 배선은 직후 좌표로, 착지 후 상태는 아래에서 따로 본다.
	t.check(seal3 != null and seal3.global_position == cp5,
		"레벨 5에서 사망하면 물범이 마지막 체크포인트로 부활한다 (%s)" % str(seal3.global_position))
	t.check(berg3 != null and berg3.global_position.x < cp5.x - 200.0,
		"사망 부활 시 빙산이 물범 뒤로 재배치된다")
	t.check(not GameState.is_dead(), "체크포인트 부활로 죽음 상태가 풀린다")
	await t.step_frames(tree, 30)
	t.check(seal3 != null and seal3.is_on_floor() and not seal3.is_fallen(),
		"체크포인트에서 부활한 물범이 지면에 선다")

	main.queue_free()
	await t.step_frames(tree, 2)
	# GameState 는 오토로드라 뒤따르는 스위트가 하트·물고기 상태를 물려받는다.
	GameState.reset_for_level()
