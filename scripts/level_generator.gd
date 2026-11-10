class_name LevelGenerator
extends RefCounted

# 시드 기반 레벨 생성 (설계 8.1·8.3). LevelData 하나를 받아 지형·발판·꼬리치기
# 장치·마커를 가진 Node2D 트리를 돌려준다. 시드가 고정이므로 같은 데이터는 항상
# 같은 결과를 만든다 (랜덤이 아니다).
#
# 좌표 규칙: y+ 는 아래(Engine rule 2). 지면 표면을 y=0 으로 두고 공중 발판은
# 음수 y 에 둔다.
#
# 고저차의 셈법 (설계 8.3). 점프 상승 한계는 320²/(2×900) ≈ 57px 이므로 48px
# 발판은 점프로 닿고, 96px 발판은 48px 발판에서 연쇄로 닿는다. 꼬리치기 반동은
# 최대 높이를 늘리지 않고 공중 체류만 약 43px 늘리므로, 반동이 이동 수단이 되는
# 자리는 "점프 도달 92px 을 넘는 수평 거리" 다. 반동 틈의 폭은 실측한 "반동 한
# 번의 도달" RECOIL_REACH_CAP 으로 조여서, 반동 없이는 못 건너지만 반동 한 번으로는
# 건너는 틈만 만든다.

const FIRST_SEGMENT_WIDTH := 600.0   # 넓고 안전한 연습 구간 (설계 8.1)
const LAST_SEGMENT_WIDTH := 400.0    # 마지막 세그먼트, 끝에 엄마 빙하
const GROUND_THICKNESS := 240.0
const GAP_MIN := 40.0
const SEGMENT_MIN := 240.0
const SEGMENT_MAX := 420.0
const PLATFORM_THICKNESS := 16.0
const PLATFORM_WIDTH := 56.0
const STEP_LOW := 48.0                # 점프로 닿는 한 단
const STEP_HIGH := 96.0               # STEP_LOW 에서 연쇄로 닿는 두 단
const WALL_WIDTH := 28.0
const WALL_HEIGHT_MIN := 90.0        # 점프 상승(약 57px)으로는 넘을 수 없다
const WALL_HEIGHT_MAX := 110.0
const RECOIL_TARGET_SIZE := 26.0
const HAZARD_FOOTPRINT := 64.0        # 얇은 얼음·물 씬의 충돌 상자 가로
# 물은 "빙하 틈"(설계 5.3)이므로 지면을 파고 그 안에 채운다. 씬의 충돌 상자는
# 64×64 이고 노드 원점이 한가운데이므로, 노드를 지면 표면 아래로 내리면 상자
# 윗면이 걸어 다니는 면보다 아래에 놓인다. 이래야 물 위를 점프해 건널 수 있다.
const WATER_PIT_Y := 40.0
const ICE_BLOCK_WIDTH := 32.0         # hazard_ice_block.tscn 의 원래 크기
const ICE_BLOCK_HEIGHT := 100.0
const RECOIL_HOP := 96.0             # 평면 점프 도달(92px)을 넘는 홉 길이
const RECOIL_REACH_CAP := 142.0      # 꼬리치기 반동 한 번으로 실제 건널 수 있는 최대 폭 (실측 142.3px)
const SPAWN_X := 120.0
const SPAWN_CLEARANCE := 200.0        # 첫 얼음 벽은 스폰에서 이만큼 떼어 둔다
const GOAL_MARGIN := 120.0
const GOAL_HEIGHT := 120.0
const SAFE_MARGIN := 300.0           # 마지막 구간에는 적·위험을 두지 않는다
const HOLE_REGION_END := 600.0       # 반동 틈은 마지막 세그먼트 앞까지
const ENEMY_HEAD_RATIO := 0.3        # 앞 1/3 구간의 밀도 배율 (설계 8.1)
const FISH_GROUND_Y := -14.0

# ── 적 자리 (태스크 10 후속 수정) ──
#
# 적 몸체 높이 (enemy_crab.tscn / enemy_seagull.tscn 의 충돌 상자). 지면 표면
# (y=0) 위에 몸체를 앉히려면 원점을 반높이만큼 위에 둬야 한다. 예전에는 24px
# 게와 28px 갈매기에 같은 -14.0 을 써서 게가 2px 땅에 파묻혔다.
const CRAB_HEIGHT := 24.0
const SEAGULL_HEIGHT := 28.0
# 충돌 상자 아랫면을 지면 표면(y=0)에 정확히 붙이면(반높이만 올리면) 몸이
# 얼음과 접촉한 상태가 된다. 이 상태에서 다른 적과 몸이 눌려 지면 모서리에
# 파묻히면 물리 서버가 몸을 1px/frame 씩 아래로 밀어넣어 적이 레벨 아래로
# 가라앉는다 (실측: 게 23px, 갈매기 25px). 그래서 몸체 반높이를 기본으로 두고
# 1px 의 여유를 더한다. 1px 는 눈에 보이지 않으면서 접촉을 완전히 끊는다.
# y+는 아래이므로 음수가 위이며, 이 값은 반높이보다 1px 높은 값이다.
const ENEMY_SURFACE_CLEARANCE := 1.0
const CRAB_GROUND_Y := -(CRAB_HEIGHT * 0.5 + ENEMY_SURFACE_CLEARANCE)    # -13.0
const SEAGULL_GROUND_Y := -(SEAGULL_HEIGHT * 0.5 + ENEMY_SURFACE_CLEARANCE)  # -15.0
# 적끼리의 최소 중심 거리. 몸체는 게 32·갈매기 36 폭이므로 반폭만 해도 36 이다.
# 간격이 부족하면 두 캐릭터가 겹쳐 태어나고, 물리 서버가 겹침을 푸는 과정에서
# 한쪽을 밀어내며 밀려난 수직 속도가 적 스크립트에서 리셋되지 않아 그 적이
# 레벨 밖으로 영구히 표류한다 (실측: L5 Enemy_5 가 182px 떠오른 뒤 복귀 못함).
const ENEMY_MIN_SPACING := 72.0
# 이미 설치된 충돌체(얼음 벽 28 폭·반동 대상 26 폭·위험 요소 발자국 64 폭)와의
# 최소 거리. 가장 넓은 위험 요소 발자국의 반폭 32 에 적 반폭 18 을 더한 값.
const ENEMY_KEEPOUT := 56.0
# 위험 요소끼리의 최소 거리 (예전 _spread_x 가 쓰던 50 에 발자국 반폭 여유를 더함).
const HAZARD_SPACING := 52.0
# ── 겹치지만은 않는 하한 (2단계 탐색의 두 번째 단계) ──
# 밀도가 높은 구간에서는 권장 간격을 채울 수 없다. 그때도 겹쳐 태어나면 안
# 되므로, "충돌 상자가 닿지 않는" 거리를 하한으로 한 번 더 찾는다.
const NO_OVERLAP_ENEMY := 40.0     # 적 반폭 합(게 16 + 갈매기 18 = 34) + 6
const NO_OVERLAP_KEEPOUT := 54.0   # 위험 요소 반폭 32 + 적 반폭 18 + 4
const NO_OVERLAP_HAZARD := 68.0    # 위험 요소 발자국 64 + 4
# 자리 탐색. 원하는 x 에서 이 간격씩 양쪽으로 넓혀 가며 조건을 만족하는 첫
# 난수를 소모하지 않으므로 생성 순서와 레벨 모양은 그대로다.
const SEARCH_STEP := 4.0
const SEARCH_REACH := 400.0
# 지면 세그먼트 끝에서 이만큼 안쪽에만 자리를 잡는다. 위험 요소 발자국(64 폭,
# 반 32)이 세그먼트 경계를 넘지 않는 값과 같고, 적 몸체 반폭(18)의 두 배 이상이다.
const EDGE_MARGIN := 40.0

const GROUP_ENEMY := "enemy"
const GROUP_HAZARD := "hazard"
const GROUP_SWAT_TARGET := "swat_target"
const GROUP_CHECKPOINT := "checkpoint"
const GROUP_GOAL := "goal"
const GROUP_FISH := "fish"

# 위험 요소 씬 (태스크 9). 플레이스홀더 마커가 아니라 실제 씬을 인스턴스화한다:
# 마커는 그룹에만 들어 있어 게임에 아무것도 나타나지 않는다.
const SCENE_THIN_ICE := preload("res://scenes/entities/hazard_thin_ice.tscn")
const SCENE_ICICLE := preload("res://scenes/entities/hazard_icicle.tscn")
const SCENE_WATER := preload("res://scenes/entities/hazard_water.tscn")
const SCENE_ICE_BLOCK := preload("res://scenes/entities/hazard_ice_block.tscn")
const SCENE_FISH := preload("res://scenes/entities/pickup_fish.tscn")
# 적 씬 (태스크 10 리뷰). 플레이스홀더 마커가 아니라 실제 씬을 인스턴스화한다:
# 마커는 "enemy" 그룹에만 들어 있어 게임에 적이 한 마리도 나타나지 않는다.
const SCENE_CRAB := preload("res://scenes/entities/enemy_crab.tscn")
const SCENE_SEAGULL := preload("res://scenes/entities/enemy_seagull.tscn")
# 빙산 씬 (태스크 13). has_time_pressure 가 true 인 레벨의 시간 압박.
const SCENE_ICEBERG := preload("res://scenes/entities/iceberg.tscn")

const TEX_GROUND := preload("res://assets/sprites/env/ground_tile.png")
const TEX_PLATFORM := preload("res://assets/sprites/env/platform_tile.png")
const TEX_MOM_FLOE := preload("res://assets/sprites/env/mom_floe.png")

# 엄마 빙하 표시 크기. 스프라이트의 불투명 영역이 112×94 이므로 그 기준으로
# 스케일을 환산한다.
const MOM_FLOE_WIDTH := 160.0
const MOM_FLOE_HEIGHT := 64.0
const ICEBERG_SPEED := 40.0             # px/s, 왼쪽→오른쪽
# iceberg.tscn 의 CollisionShape2D·폴리곤 높이와 같아야 한다: 노드 원점을 지면
# 표면(y=0) 위에 세우려면 반높이만큼 올려 두기 때문이다. 폭은 위치를 정하는 데
# 쓰이지 않으므로 여기에 두지 않는다.
const ICEBERG_HEIGHT := 120.0
# 스폰 뒤쪽에 두는 거리. ICEBERG_SPEED 로 이동하므로 물범은 15초 의 여유를 갖는다.
const ICEBERG_LEAD := 600.0

const COLOR_GROUND := Color(0.62, 0.78, 0.92)
const COLOR_PLATFORM := Color(0.45, 0.65, 0.86)
const COLOR_MARK := Color(0.98, 0.98, 0.98)


func generate(data: LevelData) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = data.seed_value

	var root := Node2D.new()
	root.name = "Level_%d" % data.level_index
	var terrain := _container(root, "Terrain")
	var devices := _container(root, "Devices")
	var actors := _container(root, "Actors")
	var markers := _container(root, "Markers")

	# 반동 틈(장치 B)을 먼저 정한다: 지면은 이 구간을 뚫려 있게 만든다.
	var holes := _plan_recoil_holes(data, rng)
	var flat_gaps: Array[float] = []
	var segments := _build_segments(data, holes, rng, flat_gaps)

	var wall_count := _add_swat_walls(data, segments, rng, devices)
	var platforms := _add_platforms(segments, rng, terrain)
	var recoils := _add_recoil_gaps(holes, rng, devices)

	# 위험 요소의 x 자리를 먼저 정한다. 적은 이 자리를 피해 배치돼야 하므로(겹치면
	# 적이 위험 요소 상자 안에 태어난다) 적보다 앞서 계산한다. kind 배정은 아래
	# _place_hazards 에서 rng 로 섞어 정하고, 여기서는 rng 를 쓰지 않으므로 이
	# 계산을 앞당겨도 난수 Stream 이 바뀌지 않아 레벨 모양은 그대로다.
	var hazard_xs := _plan_hazard_x(data, segments)

	# 이미 설치된 꼬리치기 대상(얼음 벽·반동 대상)의 x. 여기와 위험 요소 자리를
	# 합쳐 적이 겹쳐 태어나지 않을 keep-out 목록으로 쓴다.
	var keep_out: Array = []
	_collect_group_x(root, GROUP_SWAT_TARGET, keep_out)
	for hx in hazard_xs:
		keep_out.append(hx)

	_place_enemies(data, segments, keep_out, rng, actors)
	# 밀려오는 빙산 (태스크 13). 시간 압박이 있는 레벨에만 레벨 시작점 뒤쪽에
	# 하나 둔다. rng 를 쓰지 않으므로 난수 Stream 이 그대로 보존되어 레벨 모양이
	# 바뀌지 않는다.
	if data.has_time_pressure:
		_add_iceberg(actors, SPAWN_X - ICEBERG_LEAD)
	# 지면은 위험 요소를 배치한 뒤에 만든다. 얇은 얼음과 물은 지면을 파고 들어가는
	# 구멍이므로 구멍 경계가 먼저 정해져야 지면을 자를 수 있다 (설계 5.3).
	# 지면 만들기가 rng를 쓰지 않으므로 이 순서 변경은 난수 Stream을 그대로 보존해
	# 레벨 모양이 바뀌지 않는다.
	#
	# (고드름은 _add_hazard 안에서 가장 가까운 발판 위로 x 를 옮기므로 계획한
	# 자리와 실제 자리가 다르다. 적은 계획된 자리를 피해 놓이므로 고드름에 한해
	# 그 차이만큼 가까워질 수 있다. 고드름은 Area2D 라 물리 충돌을 하지 않고
	# BabySeal 에만 반응하므로, 적이 거기 서 있어도 밀려나지 않는다.)
	var cuts := _place_hazards(data, segments, platforms, rng, actors, hazard_xs)
	var supports := _build_ground(terrain, segments, cuts)
	_bind_thin_ice(cuts, supports)
	var fish_total := _place_fish(segments, platforms, rng, actors)
	var checkpoints := _place_checkpoints(data, segments, markers)
	var goal_x := _place_goal(data, markers)

	root.set_meta("flat_gaps", flat_gaps)
	root.set_meta("swat_wall_count", wall_count)
	root.set_meta("recoil_gap_count", recoils.size())
	root.set_meta("recoil_targets", recoils)

	return {
		"root": root,
		"spawn": Vector2(SPAWN_X, 0.0),
		"checkpoints": checkpoints,
		"goal_x": goal_x,
		"fish_total": fish_total,
	}


# ---------------------------------------------------------------- 지면과 틈

# 반동 틈(장치 B)의 위치와 폭. 평면 점프 도달(92px)을 넘는 폭으로 뽑으므로 점프
# 만으로는 건널 수 없고, 꼬리치기 반동이나 디딤발판이 필요하다.
func _plan_recoil_holes(data: LevelData, rng: RandomNumberGenerator) -> Array:
	var holes: Array = []
	var count := data.recoil_gap_count
	if count <= 0 or data.recoil_max_gap_px <= 0.0:
		return holes

	var start := data.length_px * 2.0 / 3.0
	var finish := data.length_px - HOLE_REGION_END
	if finish - start < 200.0:
		return holes

	var stride := (finish - start) / float(count)
	# 인접한 틈이 겹치지 않게, 그리고 틈 사이에 설 땅이 남게 폭을 제한한다.
	# 설계 5.8 장치 B: 반동 틈은 점프만으로는 못 건너지만(> 92px) 반동 한 번으로는
	# 건너야 한다. 그래서 폭 상한은 난이도 표의 recoil_max_gap_px 가 아니라 실측한
	# 반동 도달 RECOIL_REACH_CAP 으로 한 번 더 조인다. 표의 값은 의도된 상한으로
	# 남기고, 생성기는 물리적으로 가능한 폭만 만든다.
	var max_w := minf(minf(data.recoil_max_gap_px, stride * 0.7), RECOIL_REACH_CAP)
	# 하한은 반드시 평면 점프 도달(92px)을 넘어야 한다. 못 넘으면 점프만으로
	# 건너는 평면 틈과 구분이 사라진다.
	var min_w := maxf(data.flat_max_gap_px + 20.0, 100.0)
	if min_w <= LevelData.MAX_FLAT_GAP:
		min_w = LevelData.MAX_FLAT_GAP + 1.0
	if max_w <= min_w:
		# 조인 결과로 틈을 만들 폭이 남지 않았다. 장식용으로 만들면 설계 전제가
		# 깨지므로, 이 레벨에는 반동 틈을 두지 않는다.
		return holes
	for i in count:
		var center := start + stride * (float(i) + 0.5)
		var w := _rand_range(rng, min_w, max_w)
		holes.append({"x0": center - w * 0.5, "x1": center + w * 0.5})
	return holes


# 틈을 빼면 남는 지면 덩어리들. 틈은 반동 틈으로 따로 기록되므로 여기의 간격은
# 전부 평면 점프로 건널 수 있는 폭이다.
func _solid_ranges(length_px: float, holes: Array) -> Array:
	var out: Array = []
	var cursor := 0.0
	for h: Dictionary in holes:
		var x0: float = h["x0"]
		var x1: float = h["x1"]
		if x0 > cursor + 0.001:
			out.append({"x0": cursor, "x1": x0})
		cursor = maxf(cursor, x1)
	if cursor < length_px - 0.001:
		out.append({"x0": cursor, "x1": length_px})
	return out


func _build_segments(data: LevelData, holes: Array, rng: RandomNumberGenerator, gaps: Array[float]) -> Array:
	var solids := _solid_ranges(data.length_px, holes)
	var out: Array = []
	for i in solids.size():
		var s: Dictionary = solids[i]
		var force_first := FIRST_SEGMENT_WIDTH if i == 0 else 0.0
		var force_last := LAST_SEGMENT_WIDTH if i == solids.size() - 1 else 0.0
		var parts := _subdivide(
			float(s["x0"]), float(s["x1"]), force_first, force_last,
			data.flat_max_gap_px, rng, gaps)
		for p: Dictionary in parts:
			out.append(p)
	return out


# 한 지면 덩어리를 세그먼트로 나눈다. 첫 세그먼트는 넓고 안전하게, 마지막은
# 400px 로 고정하고, 그 사이의 틈은 flat_max_gap_px 이하로만 뽑는다.
func _subdivide(x0: float, x1: float, force_first: float, force_last: float,
		flat_max: float, rng: RandomNumberGenerator, gaps: Array[float]) -> Array:
	var segs: Array = []
	var cursor := x0
	if force_first > 0.0 and x1 - x0 > force_first:
		segs.append({"x0": cursor, "x1": cursor + force_first})
		cursor += force_first

	var end_limit := maxf(x1 - force_last, cursor)
	while cursor < end_limit - 0.001:
		var remaining := end_limit - cursor
		if remaining < GAP_MIN + SEGMENT_MIN:
			# 세그먼트를 하나 더 넣을 여유가 없다. 틈을 만드는 대신 앞 세그먼트를
			# 늘려 메꾼다 (틈은 절대 flat_max 를 넘기지 않아야 하므로).
			if remaining >= GAP_MIN and remaining <= flat_max:
				break
			if segs.is_empty():
				segs.append({"x0": x0, "x1": end_limit})
			else:
				var merged: Dictionary = segs.pop_back()
				merged["x1"] = end_limit
				segs.append(merged)
			cursor = end_limit
			break
		var gap := _rand_range(rng, GAP_MIN, minf(flat_max, remaining - SEGMENT_MIN))
		gaps.append(gap)
		cursor += gap
		var w := minf(_rand_range(rng, SEGMENT_MIN, SEGMENT_MAX), end_limit - cursor)
		segs.append({"x0": cursor, "x1": cursor + w})
		cursor += w

	if force_last > 0.0 and x1 - force_last >= cursor - 0.001 and x1 - cursor > 0.001:
		var tail := (x1 - force_last) - cursor
		if tail >= GAP_MIN - 0.001:
			# 위 루프가 "넣을 여유가 없다"로 빠져나온 경우에만 여기에 도달하고,
			# 그때의 tail 은 flat_max 이하임이 보장된다.
			gaps.append(tail)
		segs.append({"x0": x1 - force_last, "x1": x1})
	return segs


# ------------------------------------------------------------ 장치 A: 얼음 벽

func _add_swat_walls(data: LevelData, segments: Array, rng: RandomNumberGenerator, parent: Node2D) -> int:
	var count := data.swat_wall_count
	if count <= 0:
		return 0
	var front_end := data.length_px / 3.0
	var slots := _wall_slots(segments, front_end, count)
	var placed := 0
	for i in count:
		# 첫 벽은 지면이 넓은 곳에 하나만, 이후 벽은 간격을 두고 배치 (설계 8.1)
		var index := int(round(float(i) * float(slots.size() - 1) / float(maxi(1, count - 1))))
		var x: float = slots[clampi(index, 0, slots.size() - 1)]
		_add_wall(parent, x, _rand_range(rng, WALL_HEIGHT_MIN, WALL_HEIGHT_MAX))
		placed += 1
	return placed


# 앞 1/3 안에 온전히 들어가는 지면 세그먼트만 후보로 삼는다. 후보가 벽 수보다
# 적으면 세그먼트를 둘로 쪼개 자리를 만든다. 임의의 x 를 snapping 하면 벽이
# 앞 1/3 밖으로 밀려나므로, 후보 세그먼트 안의 자리를 직접 고른다.
func _wall_slots(segments: Array, front_end: float, count: int) -> Array:
	var safe: Array = []
	var is_first_segment := true
	for s: Dictionary in segments:
		var lo: float = s["x0"] + 40.0
		var hi: float = s["x1"] - 40.0
		if is_first_segment:
			# 스폰 바로 앞에 벽이 서면 출발하자마자 막히므로, 첫 세그먼트에서도
			# 스폰으로부터 SPAWN_CLEARANCE 이상 떨어진 곳만 후보로 삼는다.
			lo = maxf(lo, SPAWN_X + SPAWN_CLEARANCE)
			is_first_segment = false
		if hi < lo or hi > front_end:
			continue
		safe.append({"lo": lo, "hi": hi})
	if safe.is_empty():
		var first: Dictionary = segments[0]
		var lo: float = first["x0"] + 40.0
		var hi: float = first["x1"] - 40.0
		safe.append({"lo": lo, "hi": hi if hi > lo else lo})

	var per_segment := int(ceil(float(count) / float(safe.size())))
	var slots: Array = []
	for s: Dictionary in safe:
		for k in per_segment:
			var f := (float(k) + 0.5) / float(per_segment)
			slots.append(lerpf(float(s["lo"]), float(s["hi"]), f))
	return slots


# ------------------------------------------------------------ 장치 B: 반동 틈

func _add_recoil_gaps(holes: Array, rng: RandomNumberGenerator, parent: Node2D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for hole: Dictionary in holes:
		var x0: float = hole["x0"]
		var x1: float = hole["x1"]
		# 틈 바로 앞에 반동 대상 (설계 8.1). 대상 없이 반동을 요구하면 막힌다.
		var target_x := x0 - RECOIL_TARGET_SIZE * 0.5 - 6.0
		var target := _add_recoil_target(parent, target_x)
		# 한 번의 반동(실측 최대 RECOIL_REACH_CAP px)으로 부족한 폭은 48px
		# 디딤발판을 놓는다. 홉 길이가 평면 점프 도달(92px)을 넘으므로 각 홉이
		# 반동을 강제하고, 고저차가 반동을 이동 수단으로 만든다 (설계 8.3).
		var steps := 0
		var cursor := x0 + RECOIL_HOP
		while cursor + PLATFORM_WIDTH <= x1 + 0.001:
			_add_platform_at(parent, cursor, -STEP_LOW)
			steps += 1
			cursor += RECOIL_HOP + PLATFORM_WIDTH
		out.append({
			"target": target,
			"gap_x": x0,
			"gap_width": x1 - x0,
			"target_x": target_x,
			"steps": steps,
		})
	return out


# ------------------------------------------------------------ 떠 있는 발판

func _add_platforms(segments: Array, rng: RandomNumberGenerator, parent: Node2D) -> Array:
	var out: Array = []
	var forced := 2
	for i in segments.size():
		if i == 0:
			continue    # 첫 세그먼트는 연습 공간으로 비워둔다
		var s: Dictionary = segments[i]
		if rng.randf() < 0.35 and forced <= 0:
			continue
		forced -= 1
		var x := _safe_ground_x(lerpf(float(s["x0"]), float(s["x1"]), _rand_range(rng, 0.25, 0.75)), segments)
		var low := {"x": x, "y": -STEP_LOW, "w": PLATFORM_WIDTH}
		_add_platform_at(parent, low["x"], low["y"])
		out.append(low)
		# 두 단 고저차: 48px 발판 위에 96px 발판을 연쇄로 얹는다 (설계 8.3)
		if rng.randf() < 0.5 and float(s["x1"]) - float(s["x0"]) > 300.0:
			var high := {
				"x": clampf(x + _rand_range(rng, -30.0, 30.0), float(s["x0"]) + 40.0, float(s["x1"]) - 40.0),
				"y": -STEP_HIGH,
				"w": PLATFORM_WIDTH,
			}
			_add_platform_at(parent, high["x"], high["y"])
			out.append(high)
	return out


# ------------------------------------------------------------------- 적·위험

# 적을 배치한다. keep_out 은 이미 설치된 충돌체(얼음 벽·반동 대상·위험 요소
# 자리)의 x 목록이다. 이들과, 그리고 서로 겹치지 않는 자리만 고르므로 적이
# 태어나자마자 물리 서버에 밀려나는 일이 없다 (태스크 10 후속 수정).
func _place_enemies(data: LevelData, segments: Array, keep_out: Array,
		rng: RandomNumberGenerator, parent: Node2D) -> void:
	var density := maxf(0.0, data.enemy_density)
	var kinds := data.enemy_mix
	if density <= 0.0 or kinds.is_empty():
		return

	var front_end := data.length_px / 3.0
	var front_span := maxf(0.0, front_end - FIRST_SEGMENT_WIDTH)
	var back_span := maxf(0.0, data.length_px - SAFE_MARGIN - front_end)
	var front_n := int(round(density * front_span / 1000.0 * ENEMY_HEAD_RATIO))
	var back_n := int(round(density * back_span / 1000.0))
	var total := front_n + back_n
	if total <= 0:
		return

	# enemy_mix 의 모든 종류가 한 번씩은 나오도록 순서를 만든 뒤 섞는다.
	var order: Array = []
	for k in kinds:
		order.append(k)
	while order.size() < total:
		order.append(kinds[rng.randi_range(0, kinds.size() - 1)])
	_shuffle(order, rng)

	var front_slots := _enemy_slots(segments, keep_out, FIRST_SEGMENT_WIDTH, front_end,
		front_n, ENEMY_MIN_SPACING, NO_OVERLAP_ENEMY)
	# 뒤 구간은 앞 구간의 마지막 적과 겹치지 않게 거기서부터 시작한다. 두 구간을
	# 따로 계산하면 경계(front_end)에서 앞 적과 뒤 적이 같은 자리를 쓸 수 있다.
	var back_from := front_end
	if not front_slots.is_empty():
		back_from = maxf(front_end,
			float(front_slots[front_slots.size() - 1]) + ENEMY_MIN_SPACING)
	var back_slots := _enemy_slots(segments, keep_out, back_from,
		data.length_px - SAFE_MARGIN, back_n, ENEMY_MIN_SPACING, NO_OVERLAP_ENEMY)

	var index := 0
	for ex in front_slots:
		_add_enemy(parent, ex, order[index])
		index += 1
	for ex in back_slots:
		_add_enemy(parent, ex, order[index])
		index += 1


func _place_hazards(data: LevelData, segments: Array, platforms: Array,
		rng: RandomNumberGenerator, parent: Node2D, hazard_xs: Array) -> Array:
	var allowed := _allowed_hazard_kinds(data)
	# 지면에서 파낼 구간 목록. 얇은 얼음과 물은 지면에 구멍을 내야 하므로, 위험
	# 요소를 먼저 배치하고 지면은 나중에 이 목록을 보고 자른다.
	var cuts: Array = []
	if allowed.is_empty() or data.hazard_count <= 0:
		return cuts

	var order: Array = []
	for k in allowed:
		order.append(k)
	while order.size() < data.hazard_count:
		order.append(allowed[rng.randi_range(0, allowed.size() - 1)])
	_shuffle(order, rng)

	for i in data.hazard_count:
		var kind := str(order[i])
		# 자리는 _plan_hazard_x 에서 정해 둔 것을 쓴다. 세그먼트 안 40px 이상
		# 안쪽이고 서로 HAZARD_SPACING 이상 떨어져 있으므로, 위험 요소의 발자국
		# (64px)이 세그먼트 경계에 걸려 구멍이 세그먼트를 넘어가는 일이 없다.
		var x: float = float(hazard_xs[i])
		var node := _add_hazard(parent, x, kind, platforms)
		var record := {"node": node, "kind": kind, "support": false, "x0": 0.0, "x1": 0.0}
		if kind == "thin_ice" or kind == "water":
			record["x0"] = x - HAZARD_FOOTPRINT * 0.5
			record["x1"] = x + HAZARD_FOOTPRINT * 0.5
			# 얇은 얼음 자리에는 무너질 수 있는 지면을 따로 깐다. 물 자리는 아예
			# 비워 둔다 (틈).
			record["support"] = kind == "thin_ice"
		cuts.append(record)
	return cuts


# 위험 요소의 x 자리를 정한다. 적 배치보다 앞서 돌지만 rng 를 쓰지 않으므로
# (kind 배정은 _place_hazards 의 _shuffle 가 담당) 난수 Stream 은 그대로다.
#
# 어차피 이 자리를 피해 적을 놓아야 하므로(태스크 10 후속 수정: 적이 위험 요소
# 상자 안에 태어나면 안 된다) 적보다 먼저 계산한다. 예전에는 적과 위험 요소가
# 각자 따로 used 목록을 써서, 같은 x 에 적과 위험 요소가 겹쳐질 수 있었다.
func _plan_hazard_x(data: LevelData, segments: Array) -> Array:
	if _allowed_hazard_kinds(data).is_empty() or data.hazard_count <= 0:
		return []
	var span_start := FIRST_SEGMENT_WIDTH
	var span_end := data.length_px - SAFE_MARGIN
	if span_end - span_start <= 0.0:
		return []
	return _spread_slots(segments, [],
		_free_ranges(segments, [], 0.0, span_start, span_end),
		data.hazard_count, HAZARD_SPACING, NO_OVERLAP_HAZARD, span_start)


func _allowed_hazard_kinds(data: LevelData) -> Array:
	var out: Array = []
	if data.allows_thin_ice:
		out.append("thin_ice")
	if data.allows_water:
		out.append("water")
	if data.allows_icicle:
		out.append("icicle")
	return out


# ------------------------------------------------------- 물고기·체크포인트·목표

func _place_fish(segments: Array, platforms: Array, rng: RandomNumberGenerator, parent: Node2D) -> int:
	var total := 0
	for i in segments.size():
		var s: Dictionary = segments[i]
		var n := 1 + rng.randi_range(0, 1)
		for j in n:
			var x := _safe_ground_x(lerpf(float(s["x0"]), float(s["x1"]), (float(j) + 0.5) / float(n)), segments)
			var y := FISH_GROUND_Y
			if not platforms.is_empty() and rng.randf() < 0.4:
				var p := _nearest_platform(platforms, x)
				if not p.is_empty():
					x = float(p["x"])
					y = float(p["y"]) - 18.0
			_add_fish(parent, x, y, total)
			total += 1
	return total


func _place_checkpoints(data: LevelData, segments: Array, parent: Node2D) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := data.checkpoint_count
	if n <= 0:
		return out
	for i in n:
		var x := _safe_ground_x(data.length_px * float(i + 1) / float(n + 1), segments)
		var node := _marker(parent, "Checkpoint_%d" % i, GROUP_CHECKPOINT, Vector2(x, 0.0), COLOR_MARK, 10.0)
		node.set_meta("index", i)
		out.append(Vector2(x, 0.0))
	return out


func _place_goal(data: LevelData, parent: Node2D) -> float:
	var goal_x := data.length_px - GOAL_MARGIN
	var node := _marker(parent, "Goal", GROUP_GOAL, Vector2(goal_x, -GOAL_HEIGHT * 0.5), COLOR_MARK, 18.0)
	node.set_meta("level_index", data.level_index)
	# 엄마가 서는 빙하. 지면 표면(y=0) 위에 올려서 엄마와 같은 바닥선을 쓴다.
	var floe := Sprite2D.new()
	floe.name = "MomFloe"
	floe.texture = TEX_MOM_FLOE
	floe.position = Vector2(goal_x, -MOM_FLOE_HEIGHT * 0.5)
	floe.scale = Vector2(MOM_FLOE_WIDTH / 112.0, MOM_FLOE_HEIGHT / 94.0)
	floe.z_index = -1
	parent.add_child(floe)
	return goal_x


# ------------------------------------------------------------------- 노드 조립

func _container(parent: Node2D, name: String) -> Node2D:
	var node := Node2D.new()
	node.name = name
	parent.add_child(node)
	return node


# is_support=true 인 지면은 얇은 얼음이 깨질 때 함께 치우는 별도 조각이다.
func _add_ground(parent: Node2D, x0: float, x1: float, is_support: bool = false) -> StaticBody2D:
	var w := maxf(1.0, x1 - x0)
	var body := StaticBody2D.new()
	var label := "Ground"
	if is_support:
		label = "IceFloor"
	body.name = "%s_%d" % [label, parent.get_child_count()]
	body.position = Vector2(x0 + w * 0.5, GROUND_THICKNESS * 0.5)
	body.add_child(_collision(Vector2(w, GROUND_THICKNESS)))
	body.add_child(_box(w, GROUND_THICKNESS, COLOR_GROUND))
	body.add_child(_tile_sprite(TEX_GROUND, w, GROUND_THICKNESS))
	parent.add_child(body)
	return body


# 세그먼트들을 지면으로 만들되, cuts 로 받은 구간은 빼 버린다.
#
# 얇은 얼음 자리에는 대신 따로 떼어 낸 지면(IceFloor)을 깐다. 물범은 그 위에
# 0.3초간 서 있을 수 있고, 얇은 얼음이 무너질 때 이 조각이 함께 사라져 실제로
# 추락한다 (설계 5.3 "밟으면 0.3초 후 깨지고 추락").
#
# 물 자리에는 아무것도 깔지 않는다. 빙하 틈이므로 구멍 그대로이고, 물판은 구멍
# 안에 채워진다.
func _build_ground(parent: Node2D, segments: Array, cuts: Array) -> Dictionary:
	var supports: Dictionary = {}
	for s: Dictionary in segments:
		var x0: float = s["x0"]
		var x1: float = s["x1"]
		var local: Array = []
		for c: Dictionary in cuts:
			if float(c["x1"]) <= x0 + 0.001 or float(c["x0"]) >= x1 - 0.001:
				continue
			local.append(c)
		local.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["x0"]) < float(b["x0"]))
		var cursor := x0
		for c: Dictionary in local:
			var cx0: float = maxf(float(c["x0"]), x0)
			var cx1: float = minf(float(c["x1"]), x1)
			if cx0 > cursor + 0.001:
				_add_ground(parent, cursor, cx0)
			if bool(c["support"]):
				supports[c["node"]] = _add_ground(parent, cx0, cx1, true)
			cursor = cx1
		if cursor < x1 - 0.001:
			_add_ground(parent, cursor, x1)
	return supports


# 얇은 얼음이 깨질 때 그 아래 지면 조각을 함께 치우는 콜백을 만든다.
func _collapse_support(support: StaticBody2D) -> Callable:
	return func() -> void:
		if is_instance_valid(support):
			support.queue_free()


# 얇은 얼음의 collapsed 신호를 그 아래 지면 조각에 연결한다.
#
# ThinIce 자체는 Area2D라 물리 지면이 아니다 (hazard_thin_ice.gd 주석). 서 있을 수
# 있는 표면은 레벨의 StaticBody2D 지면이므로, "밟으면 0.3초 후 깨지고 추락"
# (설계 5.3)을 성립시키려면 깨지는 순간 그 지면도 함께 사라져야 한다.
#
# 고른 쪽: 생성기가 얇은 얼음 자리의 지면을 별도 조각(IceFloor)으로 떼어 두고,
# 여기서 신호를 연결해 함께 치운다. ThinIce 쪽이 레벨 지면을 직접 찾게 하는 대안
# 은 씬이 레벨 구조를 알아야 하므로 버렸다.
func _bind_thin_ice(cuts: Array, supports: Dictionary) -> void:
	for c: Dictionary in cuts:
		if not bool(c["support"]):
			continue
		var support: StaticBody2D = supports.get(c["node"], null)
		if support == null:
			continue
		var thin := c["node"] as ThinIce
		if thin == null:
			continue
		thin.collapsed.connect(_collapse_support(support))


func _add_platform_at(parent: Node2D, x: float, y: float) -> void:
	var body := StaticBody2D.new()
	body.name = "Platform_%d" % parent.get_child_count()
	body.position = Vector2(x, y + PLATFORM_THICKNESS * 0.5)
	body.add_child(_collision(Vector2(PLATFORM_WIDTH, PLATFORM_THICKNESS)))
	body.add_child(_box(PLATFORM_WIDTH, PLATFORM_THICKNESS, COLOR_PLATFORM))
	body.add_child(_tile_sprite(TEX_PLATFORM, PLATFORM_WIDTH, PLATFORM_THICKNESS))
	parent.add_child(body)


# 얼음 벽 (설계 5.8 장치 A). 실제 씬을 인스턴스화한다: 꼬리치기를 받으면
# IceBlock._on_swatted() 가 스스로 queue_free() 하므로, 플레이스홀더
# StaticBody2D 로 만들면 벽이 꼬리치기를 받아도 그대로 서 있어 레벨이 막힌다.
func _add_wall(parent: Node2D, x: float, h: float) -> void:
	var body := SCENE_ICE_BLOCK.instantiate() as StaticBody2D
	body.name = "IceWall_%d" % parent.get_child_count()
	# 씬의 블록은 32×100 이다. 표가 의도한 폭/높이로 스케일한다. 2D 물리 서버는
	# 비균일 스케일도 충돌 상상자에 반영한다 (탐측으로 확인).
	body.scale = Vector2(WALL_WIDTH / ICE_BLOCK_WIDTH, h / ICE_BLOCK_HEIGHT)
	body.position = Vector2(x, -h * 0.5)
	body.add_to_group(GROUP_SWAT_TARGET)
	body.set_meta("kind", "ice_wall")
	body.set_meta("breakable", true)
	parent.add_child(body)


# 반동 틈 앞의 반동 대상 (설계 5.8 장치 B / 8.1 "작은 얼음 블록"). 얼음 벽과
# 같은 씬을 쓰되, 표가 의도한 작은 크기로 스케일한다.
func _add_recoil_target(parent: Node2D, x: float) -> StaticBody2D:
	var body := SCENE_ICE_BLOCK.instantiate() as StaticBody2D
	body.name = "RecoilTarget_%d" % parent.get_child_count()
	body.scale = Vector2(
		RECOIL_TARGET_SIZE / ICE_BLOCK_WIDTH, RECOIL_TARGET_SIZE / ICE_BLOCK_HEIGHT)
	body.position = Vector2(x, -RECOIL_TARGET_SIZE * 0.5)
	body.add_to_group(GROUP_SWAT_TARGET)
	body.set_meta("kind", "ice_block")
	body.set_meta("breakable", true)
	parent.add_child(body)
	return body


# 실제 적 씬을 인스턴스화한다 (태스크 10 리뷰). 예전에는 kind 메타만 가진
# _marker Node2D 를 내서 게임에 적이 한 마리도 나타나지 않았다. 적은 설계 5.3의
# 꼬리치기 강제 장치(게는 꼬리치기로만 제거)이므로, 적이 없으면 레벨 2~5에
# 꼬리치기를 강제하는 수단이 사라져 꼬리치기가 장식이 된다. 씬이 자기 기본값
# (patrol_range 80·speed 40 / flight_range 200·speed 90·왼쪽 비행)을 갖추므로
# 여기서 덮어쓰지 않는다. "enemy" 그룹은 BabySeal.Hurtbox 의 경로 판정에 쓰인다.
#
# y 는 각 종류의 몸체 높이에서 나온다 (Part C). 게 충돌 상자는 32×24, 갈매기는
# 36×28 이므로 반높이는 12 / 14 다. 예전에는 둘 다 -14.0 을 써서 게가 2px 땅에
# 파묻혔다. 거기서 더해지는 ENEMY_SURFACE_CLEARANCE(1px)는 접촉을 끊기 위한
# 여유다(위 상수 주석). 이 값들은 각 씬의 CollisionShape2D 높이와 맞춰야 하므로,
# 씬 크기를 바꾸면 여기도 함께 고친다.
func _add_enemy(parent: Node2D, x: float, kind: String) -> void:
	var scene: PackedScene = SCENE_CRAB
	var y := CRAB_GROUND_Y
	match kind:
		"seagull":
			scene = SCENE_SEAGULL
			y = SEAGULL_GROUND_Y
	var node := scene.instantiate() as Node2D
	node.name = "Enemy_%d" % parent.get_child_count()
	node.position = Vector2(x, y)
	node.add_to_group(GROUP_ENEMY)
	node.set_meta("kind", kind)
	parent.add_child(node)


# 밀려오는 빙산 (태스크 13). 시간 압박이 있는 레벨의 시작점 뒤쪽에 하나 세운다.
# 소프트 월이라 즉사가 아니라 하트 1 + 왼쪽 넉백이므로(iceberg.gd 주석) 레벨을
# 막지 않는다. 부활 시 재배치 규칙도 iceberg.gd 가 갖는다.
func _add_iceberg(parent: Node2D, x: float) -> void:
	var berg := SCENE_ICEBERG.instantiate() as Area2D
	berg.speed = ICEBERG_SPEED
	# y+는 아래이므로 지면 표면(y=0) 위에 세우려면 반높이만큼 올린다.
	berg.position = Vector2(x, -ICEBERG_HEIGHT * 0.5)
	parent.add_child(berg)


# 실제 위험 요소 씬을 인스턴스화한다 (태스크 9). 예전에는 kind 메타만 가진
# _marker Node2D 를 내서 게임에 아무것도 나타나지 않았다.
func _add_hazard(parent: Node2D, x: float, kind: String, platforms: Array) -> Node2D:
	var scene: PackedScene = SCENE_THIN_ICE
	var y := -8.0
	match kind:
		"icicle":
			scene = SCENE_ICICLE
			# 고드름은 발판 아래에 매달리는 천장이 된다 (설계 8.3).
			if not platforms.is_empty():
				var p := _nearest_platform(platforms, x)
				if not p.is_empty():
					x = float(p["x"])
					y = float(p["y"])
		"water":
			scene = SCENE_WATER
			# 물은 빙하 틈 안에 채운다. 지면 표면(y=0) 아래로 내려야 걸어 다니는
			# 면과 겹치지 않고, 점프로 건널 수 있다.
			y = WATER_PIT_Y
	var node := scene.instantiate() as Node2D
	node.name = "Hazard_%d" % parent.get_child_count()
	node.position = Vector2(x, y)
	node.add_to_group(GROUP_HAZARD)
	node.set_meta("kind", kind)
	parent.add_child(node)
	return node


func _add_fish(parent: Node2D, x: float, y: float, index: int) -> void:
	var node := SCENE_FISH.instantiate() as Area2D
	node.name = "Fish_%d" % index
	node.position = Vector2(x, y)
	node.add_to_group(GROUP_FISH)
	node.set_meta("index", index)
	parent.add_child(node)


func _marker(parent: Node2D, name: String, group: String, position: Vector2,
		color: Color, size: float) -> Node2D:
	var node := Node2D.new()
	node.name = name
	node.position = position
	node.add_to_group(group)
	node.add_child(_box(size, size, color))
	parent.add_child(node)
	return node


func _collision(size: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	return shape


func _box(w: float, h: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.name = "Visual"
	poly.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])
	poly.color = color
	return poly


# 지면/플랫폼 타일 스프라이트를 직사각형에 맞춰 늘려 깐다. 타일 아래의
# COLOR_GROUND/COLOR_PLATFORM 박스가 그대로 남아 있어, 스프라이트의 투명
# 여백(불투명 bbox 54×35)은 박스 색이 메운다.
func _tile_sprite(tex: Texture2D, w: float, h: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "TileSprite"
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(-w * 0.5, -h * 0.5)
	sprite.scale = Vector2(w / 64.0, h / 64.0)
	return sprite


# ----------------------------------------------------------------------- 유틸

func _rand_range(rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	if hi <= lo:
		return lo
	return rng.randf_range(lo, hi)


func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


# 원하는 x 가 틈 한가운데면 가장 가까운 지면 세그먼트 중심으로 옮기고, 세그먼트
# 안에 있지만 끝에서 40px 안쪽이면 여유가 생길 때까지 당긴다. 마커가 허공에 떠
# 있거나 틈 입구에 파묻히는 것을 막기 위한 장치.
func _safe_ground_x(x: float, segments: Array) -> float:
	for s: Dictionary in segments:
		var lo: float = s["x0"]
		var hi: float = s["x1"]
		if x >= lo - 0.001 and x <= hi + 0.001:
			return clampf(x, lo + 40.0, hi - 40.0)
	var best := -1.0
	var best_dist := INF
	for s: Dictionary in segments:
		var center := (float(s["x0"]) + float(s["x1"])) * 0.5
		var d := absf(center - x)
		if d < best_dist:
			best_dist = d
			best = center
	return best


# ── 자리 고르기 (태스크 10 후속 수정) ──
#
# 예전의 _spread_x 는 (a) 이미 쓴 자리만 보고 얼음 벽·반동 대상·위험 요소를 전혀
# 보지 못했고, (b) 밀어낸 자리가 지면 위인지 확인하지 않았으며, (c) 간격이
# 부족하면 세그먼트 끝으로 보내 또 다른 겹침을 만들었다. 그 결과 적이 서로
# 겹쳐 태어나 물리 서버에 밀려났고, 밀려난 수직 속도가 리셋되지 않아 한 적이
# 레벨 밖으로 영구히 표류했다 (실측: L5 Enemy_5, 182px).
#
# 고친 방식은 "원하는 자리에서 가까운 쪽으로 밀어내기"가 아니라, 애초에 자리를
# 놓을 수 있는 구간(_free_ranges) 을 먼저 계산하고 그 안에 개수만큼 고르게
# 나눠 놓는 것이다. 이렇게 하면 막힌 구간(반동 틈 주변의 좁은 지면, 얼음 벽·
# 반동 대상·위험 요소 주변)은 애초에 후보가 아니므로, 겹쳐서 태어나는 자리가
# 생기지 않는다.
func _enemy_slots(segments: Array, keep_out: Array, from_x: float, to_x: float,
		count: int, spacing: float, floor_spacing: float) -> Array:
	return _spread_slots(segments, keep_out,
		_free_ranges(segments, keep_out, ENEMY_KEEPOUT, from_x, to_x),
		count, spacing, floor_spacing, from_x)


# [from_x, to_x] 안에서 자리를 놓을 수 있는 구간들. 지면 세그먼트 안에서
# EDGE_MARGIN 이상 안쪽이면서, keep_out 충돌체와 keepout_spacing 이상 떨어진
# 연속 구간이다. 얇은 얼음·물로 지면이 파인 자리와, 얼음 벽·반동 대상·위험
# 요소의 발자국 주변은 후보에서 빠진다.
func _free_ranges(segments: Array, keep_out: Array, keepout_spacing: float,
		from_x: float, to_x: float) -> Array:
	var out: Array = []
	for s: Dictionary in segments:
		var lo: float = maxf(float(s["x0"]) + EDGE_MARGIN, from_x)
		var hi: float = minf(float(s["x1"]) - EDGE_MARGIN, to_x)
		if hi <= lo:
			continue
		var blocked: Array = []
		for k in keep_out:
			var kx := float(k)
			var b0 := kx - keepout_spacing
			var b1 := kx + keepout_spacing
			if b1 <= lo or b0 >= hi:
				continue
			blocked.append([maxf(b0, lo), minf(b1, hi)])
		blocked.sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0]))
		var cursor := lo
		for b in blocked:
			if float(b[0]) > cursor:
				out.append([cursor, float(b[0])])
			cursor = maxf(cursor, float(b[1]))
		if cursor < hi:
			out.append([cursor, hi])
	return out


# 가용 구간들에 count 개의 자리를 고르게 놓는다.
#
# 간격을 spacing 으로 시작해, count 개가 다 안 들어가면 겹치지만은 않는 하한
# (floor_spacing)까지 줄여가며 다시 놓는다. 적·위험 요소의 수는 반드시 보존돼야
# 한다: 개수가 줄면 레벨 2~5의 꼬리치기 강제 수단(설계 5.3)이나 설계 8.1의
# 밀도 표가 깨진다. 그래서 간격을 포기하더라 개수는 지킨다.
#
# 구간 길이에 비례한 간격으로 왼쪽부터 채우므로, 너무 좁아 못 채우는 구간은
# 건너뛰고 다음 구간으로 넘어간다.
func _spread_slots(segments: Array, keep_out: Array, ranges: Array, count: int,
		spacing: float, floor_spacing: float, from_x: float) -> Array:
	var s := spacing
	var out := _sweep_slots(ranges, count, s, from_x)
	while out.size() < count and s > floor_spacing:
		s = maxf(floor_spacing, s - 4.0)
		out = _sweep_slots(ranges, count, s, from_x)
	if out.size() < count:
		# 하한까지 줄여도 자리가 모자란다. 남은 개수는 최소 간격으로 뒤를 이어
		# 채워 개수를 보존한다 (겹침은 어차피 하한이 막는다).
		out = _pad_slots(segments, keep_out, out, count, floor_spacing, from_x)
	return out


func _sweep_slots(ranges: Array, count: int, stride: float, from_x: float) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var total := 0.0
	for r in ranges:
		total += float(r[1]) - float(r[0])
	if total <= 0.0:
		return out
	var step := maxf(stride, total / float(count))
	var x := from_x
	for r in ranges:
		var lo := float(r[0])
		var hi := float(r[1])
		x = maxf(x, lo)
		while x <= hi and out.size() < count:
			out.append(x)
			x += step
	return out


# 자리가 모자라 채우지 못한 개수를 최소 간격으로 뒤에 이어 붙인다. 가용 구간
# 밖으로 나가더라도 지면 위이고 keep_out 과 NO_OVERLAP_KEEPOUT 이상 떨어진 첫
# 자리를 쓰므로, 겹쳐서 태어나는 경우는 생기지 않는다.
func _pad_slots(segments: Array, keep_out: Array, out: Array, count: int,
		floor_spacing: float, from_x: float) -> Array:
	var last: float = float(out[out.size() - 1]) if not out.is_empty() else from_x
	var guard := 0
	var steps := int(SEARCH_REACH / SEARCH_STEP)
	while out.size() < count and guard < count * 8:
		guard += 1
		var found := false
		for k in steps + 1:
			var cand: float = last + floor_spacing + float(k) * SEARCH_STEP
			if _on_solid_ground(cand, segments) \
					and _min_gap(cand, keep_out) >= NO_OVERLAP_KEEPOUT:
				out.append(cand)
				last = cand
				found = true
				break
		if not found:
			break
	return out


# x 가 지면 세그먼트 안에서 EDGE_MARGIN 이상 안쪽이면 True. 틈(구멍) 위나
# 세그먼트 끝에 걸친 자리는 적이 허공에 떠 있게 하므로 후보에서 제외한다.
func _on_solid_ground(x: float, segments: Array) -> bool:
	for s: Dictionary in segments:
		if x >= float(s["x0"]) + EDGE_MARGIN and x <= float(s["x1"]) - EDGE_MARGIN:
			return true
	return false


# used 안의 자리들과 x 사이의 최소 거리. 비어 있으면 INF (아무것도 겹치지 않는다).
func _min_gap(x: float, used: Array) -> float:
	var m := INF
	for u in used:
		m = minf(m, absf(x - float(u)))
	return m


# root 아래에서 group 에 든 노드의 x 를 모은다.
func _collect_group_x(node: Node, group: String, out: Array) -> void:
	if node.is_in_group(group) and node is Node2D:
		out.append((node as Node2D).position.x)
	for c in node.get_children():
		_collect_group_x(c, group, out)


func _nearest_platform(platforms: Array, x: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for p: Dictionary in platforms:
		var d := absf(float(p["x"]) - x)
		if d < best_dist:
			best_dist = d
			best = p
	return best
