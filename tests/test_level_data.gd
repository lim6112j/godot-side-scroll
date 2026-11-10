extends RefCounted

const LENGTHS := [2400.0, 3000.0, 3600.0, 4200.0, 4800.0]
const DENSITY := [2.0, 4.0, 6.0, 8.0, 10.0]
const HAZARDS := [1, 3, 5, 8, 11]
const CHECKPOINTS := [2, 2, 2, 1, 1]
const FLAT_GAPS := [90.0, 90.0, 92.0, 92.0, 92.0]
const RECOIL_GAPS := [0.0, 0.0, 130.0, 150.0, 170.0]

func run(t: TestHelper) -> void:
    for i in 5:
        var path := "res://resources/levels/level_%d.tres" % (i + 1)
        var res := load(path) as LevelData
        t.check(res != null, "레벨 %d 리소스가 로드된다" % (i + 1))
        if res == null:
            continue
        t.check(res.level_index == i + 1, "레벨 %d 인덱스가 %d" % [i + 1, i + 1])
        t.approx(res.length_px, LENGTHS[i], 0.01, "레벨 %d 길이" % (i + 1))
        t.approx(res.enemy_density, DENSITY[i], 0.01, "레벨 %d 적 밀도" % (i + 1))
        t.check(res.hazard_count == HAZARDS[i], "레벨 %d 위험 지형 수" % (i + 1))
        t.check(res.checkpoint_count == CHECKPOINTS[i], "레벨 %d 체크포인트 수" % (i + 1))
        t.approx(res.flat_max_gap_px, FLAT_GAPS[i], 0.01, "레벨 %d 평면 최대 틈" % (i + 1))
        t.approx(res.recoil_max_gap_px, RECOIL_GAPS[i], 0.01, "레벨 %d 반동 필요 최대 틈" % (i + 1))

        # 평면 틈은 반드시 92 이하 (점프만으로 건너야 한다)
        t.check(res.flat_max_gap_px <= LevelData.MAX_FLAT_GAP + 0.01,
            "레벨 %d 평면 틈이 92 이하다" % (i + 1))

        # 꼬리치기 강제: L1은 0, L2~L5는 1 이상
        var forced: int = res.swat_wall_count + res.recoil_gap_count
        if i == 0:
            t.check(forced == 0, "레벨 1에 꼬리치기 강제 수단이 없다")
        else:
            t.check(forced >= 1, "레벨 %d에 꼬리치기 강제 수단이 있다" % (i + 1))

        # 시간 압박은 레벨 5만
        t.check(res.has_time_pressure == (i == 4), "레벨 %d 시간 압박 설정" % (i + 1))

    var l1 := load("res://resources/levels/level_1.tres") as LevelData
    t.check(l1.enemy_mix == ["crab"], "레벨 1 적 구성이 게만")
    t.check(not l1.allows_icicle, "레벨 1에 고드름 없음")
    var l5 := load("res://resources/levels/level_5.tres") as LevelData
    t.check(l5.allows_icicle, "레벨 5에 고드름 있음")
    t.check(l5.allows_water, "레벨 5에 물 있음")
    t.check(l5.enemy_mix.has("seagull"), "레벨 5에 갈매기 있음")
