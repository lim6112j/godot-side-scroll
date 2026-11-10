extends RefCounted

const ANIMS := ["idle", "run", "jump", "fall", "swat", "hurt"]
const PIVOTS := ["BodyPivot", "HeadPivot", "TailPivot", "FlipperFrontPivot", "FlipperBackPivot"]

# 허용 목록: 애니메이션 트랙이 겨눌 수 있는 프로퍼티는 피벗 여덟 개뿐이다.
# 시각 슬롯이나 도형 파츠를 겨냥한 트랙은 그림 교체를 깨뜨리므로 전부 거부한다.
#
# 태스크 3 리뷰에서 지적된 틈: 예전 검사는 "/VisualSlot/" 처럼 슬래시가 뒤에 붙는
# 경우만 잡았다. 그래서 "BodyPivot/VisualSlot:position" 처럼 슬롯 자신을 겨냥한
# 트랙이 새고, 그런 트랙이 있으면 도형을 지워도 위치가 남아 교체가 깨진다.
# 금지 목록이 아니라 허용 목록으로 뒤집어 그 급의 참조를 전부 막는다.
#
# 태스크 15: hurt 의 깜빝임을 BodyPivot:modulate:a 페이드로 구현하면서 피벗
# modulate 항목을 허용 목록에 추가했다. 피벗은 시각 슬롯이나 도형 파츠가 아니므로
# 투명도를 애니메이션해도 그림 교체 규칙을 깨뜨리지 않는다(설계 7.3).
const ALLOWED_TRACKS := [
	"BodyPivot:scale", "BodyPivot:position",
	"HeadPivot:rotation", "HeadPivot:position",
	"TailPivot:rotation", "TailPivot:position",
	"FlipperFrontPivot:rotation", "FlipperBackPivot:rotation",
	"BodyPivot:modulate:a", "HeadPivot:modulate:a", "TailPivot:modulate:a",
	"FlipperFrontPivot:modulate:a", "FlipperBackPivot:modulate:a",
]

func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree
    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as Node

    # The runner awaits run() from inside _ready(), so the tree is still busy
    # propagating ready notifications here and add_child() would be rejected.
    # Yield one physics frame first so the seal actually enters the tree.
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    var anim := seal.get_node_or_null("SealAnim") as SealAnim
    t.check(anim != null, "SealAnim 노드가 존재한다")

    for a in ANIMS:
        t.check(anim.has(a), "애니메이션 %s가 존재한다" % a)

    for p in PIVOTS:
        t.check(seal.get_node_or_null(p) != null, "피벗 %s가 존재한다" % p)
        t.check(seal.get_node_or_null(p + "/VisualSlot") != null, "%s 아래 VisualSlot이 있다" % p)
        t.check(seal.get_node_or_null(p + "/VisualSlot/PolygonPuppet") != null, "%s 아래 PolygonPuppet이 있다" % p)

    # 그림 교체 안전성: 어떤 트랙도 허용된 피벗 프로퍼티 밖을 겨냥하지 않는다
    var player := seal.get_node_or_null("SealAnim/AnimationPlayer") as AnimationPlayer
    t.check(player != null, "AnimationPlayer가 존재한다")
    var leaks: Array[String] = []
    for a in ANIMS:
        if not player.has_animation(a):
            continue
        var anim_res := player.get_animation(a)
        for i in anim_res.get_track_count():
            var path: String = anim_res.track_get_path(i)
            if not ALLOWED_TRACKS.has(path):
                leaks.append("%s -> %s" % [a, path])
    t.check(leaks.is_empty(), "어떤 애니메이션 트랙도 허용된 피벗 프로퍼티 밖을 겨냥하지 않는다: %s" % str(leaks))

    # 재생과 실제 변형
    anim.play("run")
    t.check(anim.current() == "run", "play 후 current가 run")
    var body := seal.get_node("BodyPivot") as Node2D
    var scale_before: Vector2 = body.scale
    await t.step_frames(tree, 20)
    t.check(body.scale != scale_before, "애니메이션이 BodyPivot 스케일을 실제로 변화시킨다")

    anim.play("idle")
    var tail := seal.get_node("TailPivot") as Node2D
    # 위상에 무관하게 보기: idle 루프(0.4초 = 24프레임) 한 바퀴 + 1프레임 동안
    # 회전을 매 프레임 샘플링해 진폭이 실제로 존재하는지 본다.
    #
    # 예전 검사는 "재생 직전 값과 20프레임 뒤 값의 차이 > 0.001" 이었다. 그 차이는
    # 어느 시점을 찍었는지(클락 위상)에 따라 0에 가까워질 수 있고, 실제로 그런
    # 프레임 짝이 존재한다 — 노이즈 마진 0.0033 > 임계값 0.001. 태스크 5 리뷰에서
    # 양자화된 실패 짝이 확인됐으므로, 위상을 없애는 방식으로 고친다.
    #
    # idle의 TailPivot 회전 진폭은 0.13(0.08 → -0.05)이므로 한 루프를 다 보면
    # max-min 이 그 값에 수렴한다. 임계값 0.1은 "진짜로 흔든다"를 판별하면서도
    # 프레임 양자화(한 프레임 진행 ≈ 0.0054)에 흔들리지 않는 거리다.
    var rot_min: float = tail.rotation
    var rot_max: float = tail.rotation
    for _i in 25:
        await t.step_frames(tree, 1)
        rot_min = minf(rot_min, tail.rotation)
        rot_max = maxf(rot_max, tail.rotation)
    t.check(rot_max - rot_min > 0.1,
        "애니메이션이 TailPivot 회전을 실제로 변화시킨다 (진폭 %f)" % (rot_max - rot_min))

    seal.queue_free()
