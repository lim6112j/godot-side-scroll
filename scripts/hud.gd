class_name Hud
extends CanvasLayer

# 태스크 11: HUD. 설계 5.3의 하트, 레벨 번호, 설계 5.6의 물고기 카운터를
# 화면에 그린다.
#
# 책임 분리: 진행 상태(하트 수·물고기 수·레벨 인덱스)는 GameState 오토로드가
# 가지므로 이 스크립트는 읽고 표시만 한다. 값을 직접 소유하지 않는다.
#
# 좌표 규칙: y+는 아래(Engine rule 2). 하트는 왼쪽 위에서 오른쪽으로 놓인다.

const HEART_SIZE := Vector2(16.0, 16.0)
const HEART_TEXTURE := preload("res://assets/sprites/ui/heart.png")
# 하트는 ui/heart.png 스프라이트를 그대로 꽂는다. 하트 하나당 TextureRect
# 하나이며, 컨테이너 구조는 예전 색면 임시 구조와 같으므로 set_hearts 흐름은
# 그대로 유지된다.

@onready var _heart_box: HBoxContainer = $HeartBox
@onready var _level_label: Label = $LevelLabel
@onready var _fish_label: Label = $FishLabel


func _ready() -> void:
    GameState.hearts_changed.connect(set_hearts)
    GameState.fish_changed.connect(set_fish)
    set_hearts(GameState.hearts)


# 트리에서 분리될 때 구독을 끊는다. GameState는 오토로드라 씬보다 오래 살므로,
# 연결을 남겨 두면 해제된 HUD의 set_hearts를 부르는 경로가 된다.
func _exit_tree() -> void:
    var hearts := Callable(self, "set_hearts")
    if GameState.hearts_changed.is_connected(hearts):
        GameState.hearts_changed.disconnect(hearts)
    var fish := Callable(self, "set_fish")
    if GameState.fish_changed.is_connected(fish):
        GameState.fish_changed.disconnect(fish)


# 하트를 value 개로 맞춘다. hearts_changed가 나갈 때마다 불리므로, 늘어날
# 때와 줄어들 때 모두 컨테이너를 재구성해 노드 수가 항상 value가 되게 한다.
func set_hearts(value: int) -> void:
    for child in _heart_box.get_children():
        # remove_child가 get_child_count()를 즉시 갱신하므로, queue_free()의
        # 프레임 말 플러시를 기다리지 않고 get_heart_count()가 정확하다.
        _heart_box.remove_child(child)
        child.queue_free()
    for _i in value:
        var heart := TextureRect.new()
        heart.texture = HEART_TEXTURE
        heart.custom_minimum_size = HEART_SIZE
        heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        _heart_box.add_child(heart)


func set_level(index: int) -> void:
    _level_label.text = "LEVEL %d" % index


func set_fish(collected: int, total: int) -> void:
    _fish_label.text = "물고기 %d / %d" % [collected, total]


func get_heart_count() -> int:
    return _heart_box.get_child_count()
