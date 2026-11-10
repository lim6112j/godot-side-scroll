extends RefCounted

# 태스크 14: 도형 퍼펫 → PNG 스프라이트 교체 검증 (설계 13.4).
#
# 이 게임의 중앙 건축적 보장은 "그림을 갈아도 스크립트와 애니메이션 파일을 한 줄도
# 고치지 않는다"이다. 그 보장이 깨지는 유일한 방법은 게임 로직이 시각 노드를
# 이름으로 참조하는 것이므로, 여기서는 두 가지를 본다:
#
#   1. scripts/ 안의 어떤 스크립트도 물범의 시각 노드를 이름으로 참조하지 않는다.
#   2. 진짜 PNG 대신 합성 더미 스프라이트(Image API로 만든 단색 8×8)로 모든
#      VisualSlot의 도형을 갈아끼운 뒤에도 이동·꼬리치기·애니메이션이 그대로다.
#
# PNG가 아직 도착하지 않았으므로(그림은 png-prompts.md 프롬프트로 나중에 뽑는다)
# 실제 파일은 요구하지 않는다. 교체 *메커니즘* — "VisualSlot 아래의 도형을 지우고
# 스프라이트를 붙여도 피벗 구조와 스크립트가 영향을 받지 않는가" — 가 이 검사의
# 대상이다.
#
# y+는 아래다.

const PIVOTS := ["BodyPivot", "HeadPivot", "TailPivot", "FlipperFrontPivot", "FlipperBackPivot"]

# 노드 이름으로 참조하면 안 되는 토큰. "VisualSlot"은 슬래시 없이 쓴다:
# 트랙이나 경로가 "BodyPivot/VisualSlot:position" 처럼 슬롯 자신을 겨냥하는 경우를
# 잡기 위해서다(태스크 3 리뷰의 틈과 같은 급).
const NAME_TOKENS := ["PolygonPuppet", "VisualSlot"]

# 스왑을 깨뜨리는 참조는 "이름으로 시각 노드를 address 하는 것"이다. 문자열
# 리터럴 안의 이름만 노드 참조로 본다. 타입 사용은 예외인데, level_generator.gd가
# 지형을 Polygon2D로 그리는 것은 스왑 대상이 아닌 생성기의 합법적인 사용이기
# 때문이다(파츠가 아니라 지형이고, 이 교체와 무관하다).
const TYPE_TOKEN := "Polygon2D"


func run(t: TestHelper) -> void:
    var tree := Engine.get_main_loop() as SceneTree

    # 1. 게임 스크립트가 시각 노드를 참조하지 않는다
    var offenders: Array[String] = []
    for path in _script_files("res://scripts", []):
        var text := FileAccess.get_file_as_string(path)
        # 큰따옴표로 쪼개면 홀수 인덱스가 문자열 리터럴 안쪽이다.
        var chunks := text.split('"')
        for i in chunks.size():
            var chunk: String = chunks[i]
            var in_literal: bool = (i % 2) == 1
            for token in NAME_TOKENS:
                if token in chunk:
                    offenders.append("%s 참조 %s" % [path, token])
            if in_literal and TYPE_TOKEN in chunk:
                offenders.append("%s 이 문자열로 %s 를 참조한다" % [path, TYPE_TOKEN])
    t.check(offenders.is_empty(), "게임 스크립트가 시각 노드를 참조하지 않는다: %s" % str(offenders))

    # 2. 더미 스프라이트로 교체한 물범이 게임 로직을 유지한다
    var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
    img.fill(Color.WHITE)
    var tex := ImageTexture.create_from_image(img)

    var seal := preload("res://scenes/entities/seal_baby.tscn").instantiate() as CharacterBody2D
    var collider := seal.get_node_or_null("CollisionShape2D") as CollisionShape2D
    var body_size: Vector2 = _rect_size(collider)

    # 러너가 _ready() 안에서 run()을 await하므로 트리가 ready 통지를 진행 중이다.
    # 이 상태에서 add_child하면 거부되고 물리가 아예 돌지 않으므로, 한 프레임 먼저
    # yield 한다 (태스크 2 엔진 트랩 1).
    await t.step_frames(tree, 1)
    tree.root.add_child(seal)
    await t.step_frames(tree, 2)

    for p in PIVOTS:
        var pivot := seal.get_node_or_null(p) as Node2D
        if pivot == null:
            continue
        var slot := pivot.get_node_or_null("VisualSlot") as Node2D
        if slot == null:
            continue
        var puppet := slot.get_node_or_null("PolygonPuppet") as Node2D
        if puppet != null:
            puppet.queue_free()
        var sprite := Sprite2D.new()
        sprite.texture = tex
        slot.add_child(sprite)

    # queue_free()의 실제 해제는 프레임 말 플러시에서 일어나므로, 도형이 없어진
    # 뒤의 상태를 보려면 프레임을 더 흘려보내야 한다.
    await t.step_frames(tree, 2)

    # 3. 교체가 실제로 일어났는지. 이 검사가 없면 위 행동 검사들은 도형을 그대로
    # 둔 채로도 통과한다 — 스왑을 빼 먹어도 초록이 되는 구멍이다.
    var slots := 0
    var swapped := 0
    for p in PIVOTS:
        var slot := seal.get_node_or_null(p + "/VisualSlot") as Node2D
        if slot == null:
            continue
        slots += 1
        if slot.get_node_or_null("PolygonPuppet") != null:
            continue
        for child in slot.get_children():
            var s := child as Sprite2D
            if s != null and s.texture == tex:
                swapped += 1
                break
    t.check(slots == PIVOTS.size() and swapped == slots,
        "모든 VisualSlot에서 도형이 스프라이트로 교체됐다 (%d/%d)" % [swapped, slots])

    # 4. 그림을 바꾸는 것이 물리 몸을 흔들지 않는다. 충돌 상자는 교체 전후에 같아야
    # 한다 — 스프라이트가 몸을 대신하지 않는다.
    t.check(body_size != Vector2.ZERO and _rect_size(collider) == body_size,
        "스프라이트 교체가 물범의 충돌 상자를 바꾸지 않는다 (%s)" % str(body_size))

    # 이동이 그대로 동작한다
    seal.set_test_floor(true)
    seal.velocity = Vector2.ZERO
    Input.action_press("move_right")
    await t.step_frames(tree, 30)
    t.check(seal.get_horizontal_speed() > 50.0, "스프라이트 교체 후에도 이동이 동작한다")
    Input.action_release("move_right")

    # 꼬리치기가 그대로 동작한다
    var swat := seal.get_node_or_null("SealSwat") as SealSwat
    t.check(swat != null, "스프라이트 교체 후에도 SealSwat이 있다")
    t.check(swat != null and swat.try_swat(), "스프라이트 교체 후에도 꼬리치기가 통한다")

    # 애니메이션이 그대로 동작한다
    var anim := seal.get_node_or_null("SealAnim") as SealAnim
    anim.play("run")
    t.check(anim.current() == "run", "스프라이트 교체 후에도 애니메이션이 재생된다")
    var body := seal.get_node("BodyPivot") as Node2D
    var s0: Vector2 = body.scale
    await t.step_frames(tree, 20)
    t.check(body.scale != s0, "스프라이트 교체 후에도 피벗이 애니메이션으로 변한다")

    # 테스트 지면은 queue_free() 전에 직접 걷는다. _exit_tree() 안에서
    # _despawn_test_floor() 가 body.free() 를 부르면 트리가 자식 정리 중이라
    # remove_child() 가 거부되어 exit code 134(SIGABRT) 로 죽는다
    # (test_movement·test_swat·test_iceberg 도 같은 이유로 명시적으로 걷는다).
    seal.set_test_floor(false)
    seal.queue_free()
    await t.step_frames(tree, 2)


# scripts/ 아래의 .gd 전부 (하위 디렉터리 포함). 오토로드 스크립트도 게임
# 스크립트이므로 빼지 않는다.
func _script_files(dir_path: String, out: Array[String]) -> Array[String]:
    var dir := DirAccess.open(dir_path)
    if dir == null:
        return out
    for file in dir.get_files():
        if file.ends_with(".gd"):
            out.append(dir_path.path_join(file))
    for sub in dir.get_directories():
        _script_files(dir_path.path_join(sub), out)
    return out


func _rect_size(collider: CollisionShape2D) -> Vector2:
    if collider == null:
        return Vector2.ZERO
    var shape := collider.shape as RectangleShape2D
    return shape.size if shape != null else Vector2.ZERO
