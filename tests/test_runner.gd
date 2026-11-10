extends Node

# 태스크 14: 스위트가 런타임 오류로 죽은 경우를 실패로 본다.
#
# 예전 러너는 스위트를 그냥 await 했다. GDScript에서 런타임 오류가 난 코루틴은
# 조용히 종료되므로, 검사를 하나도 내지 못한 채 죽은 스위트도 "통과"로
# 집계됐다 — 프로브 스위트 하나가 죽어도 ALL N CHECKS PASSED, exit=0 이 나왔다.
# 그 결과 태스크 9·11의 뮤테이션 증거가 약해졌다(죽은 스위트의 검사가 사라져도
# 초록이었다).
#
# 고치는 방법: 발견한 모든 스위트가 (a) 실제로 도달하고 (b) 검사를 최소 하나 이상
# 냈는지를 끝에서 확인한다. 두 조건 중 하나라도 깨지면 그 스위트가 죽은 것이다.
#
# ④ (태스크 14 리뷰 이월) 위 두 조건은 "검사를 하나도 못 낸 죽음"만 잡는다. 검사
# 두 개를 낸 뒤 null 호출로 죽은 스위트는 두 조건을 모두 통과해서
# ALL N CHECKS PASSED, exit=0 이 나왔다 (컨트롤러 재현: zzcrash: 2).
#
# 여기서는 그 중단을 잡지 못한다 — Godot 4.7.2에서 런타임 오류로 죽은 코루틴의
# await 는 조용히 반환하고, await 뒤의 문장도 그대로 실행되기 때문이다. 직접
# 확인했다(진단 스위트로 `await _boom()` 뒤의 검사가 _boom 가 죽은 뒤에도
# 실행됨). 또한 오류가 난 코루틴의 상태를 붙잡을 수도 없다:
# `var state = suite.run(t)` 와 `Callable(...).call()` 는 둘 다
# "Trying to call an async function without await" 로 거부되고,
# GDScriptFunctionState 는 4.7의 전역 타입이 아니다. 즉 스위트가 스스로
# "끝까지 갔다"고 말해 주는 수밖에 없는데, 그건 14개 파일을 고치는 일이다.
#
# 그래서 중단 탐지는 tools/test.sh 가 맡는다: 오류가 난 순간 Godot 이 stderr 에
# 남기는 SCRIPT ERROR 를 보고 실패로 돌린다. 거기에는 죽은 스위트의 파일명과
# 행이 적히고, 검사가 하나도 없는 죽음보다 넓게(제품 코드의 오류까지) 잡힌다.
#
# ④ (태스크 14 리뷰 이월) 중간에 죽는 스위트도 초록이었다. 위 두 조건은 "검사를
# 하나도 못 낸 죽음"만 잡는다 — 검사 두 개를 낸 뒤 null 호출로 죽은 스위트는 두
# 조건을 모두 통과해서 ALL N CHECKS PASSED, exit=0 이 나왔다 (컨트롤러 재현).
#
# 고치는 방법: `await suite.run(t)` **바로 다음 줄**에서 완료 플래그를 세운다.
# 코루틴이 런타임 오류로 죽으면 await 이후의 어느 문장에도 도달하지 못하므로
# 플래그는 false 로 남는다 — 그 false 자체가 중단의 증거다. (스위트마다 마지막
# 문장에 완료 마커를 넣는 대안은 14개 파일을 기계적으로 고치는 데다 마커를 빼
# 먹는 쪽이 더 약해지므로 쓰지 않는다.)

func _ready() -> void:
    var t := TestHelper.new()
    var dir := DirAccess.open("res://tests")
    if dir == null:
        t.check(false, "tests 디렉터리를 열 수 없다")
        _finish(t)
        return
    var discovered: Array[String] = []
    var ran: Array[String] = []
    for file in dir.get_files():
        if not (file.begins_with("test_") and file.ends_with(".gd")):
            continue
        if file == "test_runner.gd" or file == "test_helper.gd":
            continue
        discovered.append(file)
        t.section(file)
        var script: GDScript = load("res://tests/" + file)
        # A parse error yields a non-null GDScript that cannot be instantiated,
        # so checking null alone is not enough.
        if script == null or not script.can_instantiate():
            t.check(false, "%s 로드에 실패했다" % file)
            continue
        var suite: Object = script.new()
        if suite == null:
            t.check(false, "%s 인스턴스화에 실패했다" % file)
            continue
        if not suite.has_method("run"):
            continue
        var before: int = t.total
        var finished := false
        await suite.run(t)
        # 여기까지 도달했다는 것 자체가 "중단 없이 끝까지 돌았다"는 증거다.
        # 코루틴이 런타임 오류로 죽으면 await 뒤의 이 문장에 닿지 못하므로
        # 플래그는 false 로 남는다.
        finished = true
        ran.append(file)
        if not finished:
            t.check(false, "%s 가 실행 중 런타임 오류로 중단됐다" % file)
        elif t.total <= before:
            t.check(false, "%s 가 검사를 하나도 내지 못하고 중단됐다" % file)
    # 발견한 스위트가 전부 도달했는지. 앞 스위트가 죽어서 여기까지 오지 못한
    # 경우를 잡는다 (await 는 조용히 종료되므로 루프가 그냥 지나갈 수 있다).
    # 이 검사는 러너 자신의 것이므로 섹션을 스위트 이름에서 떼어 낸다 — 그렇지
    # 않으면 마지막 스위트(swat)의 카운트에 러너의 검사가 섞여 집계가 왜곡된다.
    t.section("runner")
    var unreached: Array[String] = []
    for f in discovered:
        if not ran.has(f):
            unreached.append(f)
    t.check(unreached.is_empty(), "발견된 모든 스위트가 실행됐다: %s" % str(unreached))
    _finish(t)

# A failing check must exit non-zero; aborting here would hang instead of reporting.
func _finish(t: TestHelper) -> void:
    print(t.summary())
    get_tree().quit(1 if not t.passed() else 0)
