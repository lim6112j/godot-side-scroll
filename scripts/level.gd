class_name Level
extends Node2D

# 레벨 조립 (태스크 10). LevelGenerator가 만든 트리를 받아 씬에 붙이고, 물범과
# 엄마, 카메라를 배치해 "도착하면 클리어"를 성립시킨다.
#
# 책임 분리: level_generator.gd가 "무엇을 어디에 둘지"를 정하고, 이 스크립트는
# 그 결과를 실제 씬 그래프에 조립한다. 생성 규칙을 여기서 다시 만들지 않는다.
#
# 좌표 규칙: y+는 아래(Engine rule 2). 지면 표면이 y=0이고, 엄마와 물범은 그
# 표면 위에 선다.

const SEAL_SCENE := preload("res://scenes/entities/seal_baby.tscn")
const MOM_SCENE := preload("res://scenes/entities/seal_mom.tscn")

@onready var _camera: CameraFollow = $Camera2D

var _seal: BabySeal = null
var _mom: MomSeal = null
var _goal_x: float = 0.0
var _completed: bool = false
# 부활 지점 (설계 5.5). 생성기의 체크포인트 좌표를 그대로 들고, 물범이 지나갈
# 때마다 "가장 멀리 간 것"으로 갱신한다. 씬을 리로드하지 않고 같은 물범
# 인스턴스를 이 자리로 되돌리므로, 이 값은 Level 인스턴스 수명과 함께 산다.
var _respawn_at: Vector2 = Vector2.ZERO
# 생성기가 만든 체크포인트 좌표 (설계 5.5). LevelGenerator._place_checkpoints()의
# 반환값을 그대로 쓴다 — 여기서 배치 규칙을 다시 만들지 않는다.
var _checkpoints: Array[Vector2] = []


# 생성 결과를 조립하고 물범을 배치해 반환한다 (설계 8.1).
func setup(data: LevelData) -> BabySeal:
    var result: Dictionary = LevelGenerator.new().generate(data)
    var root := result["root"] as Node2D
    add_child(root)

    # 엄마를 목표가 있던 자리에 세운다. 생성기의 Goal 마커는 좌표 기록일 뿐이라,
    # 실제 캐릭터가 그 자리를 차지하면 마커는 지운다 (겹쳐 보이는 것을 막는다).
    var goal_x: float = float(result["goal_x"])
    _goal_x = goal_x
    var marker := root.find_child("Goal", true, false) as Node2D
    if marker != null:
        marker.queue_free()
    var mom := MOM_SCENE.instantiate() as MomSeal
    mom.position = Vector2(goal_x, 0.0)
    add_child(mom)
    _mom = mom

    var seal := SEAL_SCENE.instantiate() as BabySeal
    seal.position = result["spawn"] as Vector2
    add_child(seal)
    _seal = seal
    _camera.target_path = seal.get_path()

    _checkpoints = result["checkpoints"] as Array[Vector2]
    # 아무 체크포인트도 지나지 않았으면 부활 지점은 레벨 시작점이다.
    _respawn_at = seal.global_position

    GameState.current_level_index = data.level_index
    GameState.fish_total = int(result["fish_total"])
    GameState.reset_for_level()
    return seal


# 부활 지점. 지나간 체크포인트가 없으면 레벨 시작점(스폰)이다 — 체크포인트가
# 하나도 없는 레벨에서도 부활은 성립해야 한다.
func respawn_position() -> Vector2:
    return _respawn_at


func _ready() -> void:
    # 사망의 단일 출처는 GameState.player_died다 (seal_baby.gd 주석). 즉사
    # (게 밟기·추락·물)는 died 시그널을 내지 않으므로, 이 신호만이 모든 사망
    # 경로를 덮는다. 여기서 끊는 이유: Level은 트리를 떼날 때 해제 큐에 들어가므로
    # 연결을 남겨 두면 해제된 Level의 부활이 뒤따르는 스위트의 사망 신호를
    # 받는 경로가 된다 (main.gd의 _exit_tree()와 같은 규칙).
    GameState.player_died.connect(_on_player_died)


func _exit_tree() -> void:
    var died := Callable(self, "_on_player_died")
    if GameState.player_died.is_connected(died):
        GameState.player_died.disconnect(died)


# 사망 → 마지막으로 통과한 체크포인트 (설계 5.5). 씬을 리로드하지 않고 같은 물범
# 인스턴스를 제자리로 되돌린다: 리로드하면 적이 전부 되살아나 구멍·물 구간이
# 클리어 불가능해진다.
#
# respawned 시그널은 main.gd가 받아 부활 직후의 파생 상태(빙산 재배치·HUD
# 물고기 카운터)를 고친다. 태스크 13에서 재배치가 생산 호출 없이 죽은 코드였던
# 것은 이 경로가 없었기 때문이다.
func _on_player_died() -> void:
    if _completed or _seal == null or not is_instance_valid(_seal):
        return
    _seal.respawn_at(respawn_position())


func _physics_process(_delta: float) -> void:
    if _completed or _seal == null:
        return
    # 도착 판정 (설계 5.4). 물범의 x가 goal_x 이상이면 클리어. Area2D 겹침을
    # 쓰지 않는 이유: 엄마는 Node2D라 물리 몸이 없고, "레벨 길이의 90% 이후에
    # 도착"이라는 설계 문장을 좌표 비교로 그대로 옮기는 쪽이 단순하다.
    if _seal.global_position.x >= _goal_x:
        _completed = true
        GameState.complete_level()
        if _mom != null and is_instance_valid(_mom):
            _mom.celebrate()

    _update_checkpoint()


# 통과한 체크포인트 추적 (설계 5.5).
#
# "통과"의 규칙: 물범의 x >= 체크포인트의 x. 체크포인트는 지면 표면(y=0)에
# 세워지므로 y는 비교하지 않는다 — 공중을 지나가는 것도 지나간 것으로 본다.
# (설계 문장은 "마지막으로 통과한 체크포인트"이고, 지나간 것은 지나간 것이다.)
#
# 뒤로 밀린 뒤에도 부활 지점이 뒤쪽으로 물러나지 않게, 가장 큰 x만 남긴다.
# 그렇지 않으면 구멍에 빠져 죽었을 때 이미 통과한 체크포인트 대신 그 앞의
# 지점에서 살아나 다시 같은 구멍에 빠지는 무한 루프가 된다.
func _update_checkpoint() -> void:
    for cp in _checkpoints:
        if cp.x <= _seal.global_position.x and cp.x > _respawn_at.x:
            _respawn_at = cp
