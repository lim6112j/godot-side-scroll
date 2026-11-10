# class_name을 붙이지 않는다: Godot는 오토로드 싱글턴과 같은 이름의 class_name을
# "hides an autoload singleton" 파싱 오류로 거부한다. 오토로드 이름 자체가
# GDScript의 전역 식별자이므로, class_name 없이도 SoundPlayer.play("jump")처럼
# 접근한다 (game_state.gd 와 같은 규칙).
extends Node

# 사운드 재생 (설계 11장). 재생은 여기만 하고, "언제 어떤 소리가 나는지"는 각
# 이벤트 지점이 자기 play() 호출로 정한다 — 이 스크립트는 게임 사건을 모른다.

signal sfx_played(name: String)

const DIR := "res://assets/sfx/"
const NAMES := ["jump", "swat", "enemy_down", "hurt", "arrive"]

# 같은 사운드가 겹쳐도 끊기지 않게 재생기는 호출마다 새로 만든다. 대신 트리에
# 재생기가 쌓이므로 두 단계로 회수한다:
#
#   1. 수명 기반 회수 (아래 _tick). 재생기의 수명은 "스트림 길이 + 여유"로 직접
#      재서, 오디오 장치 유무와 무관하게 프레임이 도는 한 풀린다.
#   2. 상한 MAX_PLAYERS. _process 가 도는 않는 상황(트리 일시정지 등)에서의
#      안전판이다. 상한에 걸리면 가장 오래된 재생기를 즉시 회수한다 — 소리가
#      겹쳐 잘리는 대신 노드가 쌓이는 쪽을 고른 것이다.
#
# 왜 수명 기반이 필요한가: headless(오디오 장치 없음)에서는 finished 시그널이
# 나지 않고 playing 도 끝나지 않는다(둘 다 직접 확인했다). finished 에만 맡기면
# 풀이 영원히 비워지지 않는다.
const MAX_PLAYERS := 12
# 수명 여유. 오디오 장치가 있으면 finished 가 정확한 종료 시점에 도착하지만,
# 헤드리스에서는 아예 오지 않으므로 이 여유만큼 더 산다.
const LIFETIME_MARGIN := 0.15

var _streams: Dictionary = {}
# 각 항목은 {"player": AudioStreamPlayer, "left": float} — 남은 수명(초).
# 타입 없는 배열로 담는다: queue_free()는 프레임 말에 실제로 풀리므로, 풀린
# 인스턴스를 타이핑된 변수에 대입하려는 순간 GDScript가 "previously freed
# instance" 오류를 낸다. 순회·필터는 Variant로 하고 해제는 is_instance_valid()
# 뒤에만 한다.
var _players: Array = []


func _ready() -> void:
    for n in NAMES:
        # NAMES가 타입 없는 배열이므로 n은 Variant다. path는 String으로 못박는다.
        var path: String = DIR + str(n) + ".wav"
        # 파일이 없으면 조용히 스킵한다. 사운드가 없어도 게임은 동작해야 한다.
        if ResourceLoader.exists(path):
            _streams[n] = load(path)


func has(name: String) -> bool:
    return _streams.has(name)


# 살아 있는 재생기 수. 풀이 실제로 회수되는지를 보기 위한 조회 창이다
# (tests/test_sound.gd가 헤드리스 회수를 검증한다).
func player_count() -> int:
    return _players.size()


func play(name: String) -> void:
    if not _streams.has(name):
        return
    if _players.size() >= MAX_PLAYERS:
        _release_oldest()
    var player := AudioStreamPlayer.new()
    add_child(player)
    player.stream = _streams[name]
    # 오디오 장치가 있으면 재생이 끝난 정확한 시점에, 없으면 수명 만료 시 풀린다.
    player.finished.connect(_release.bind(player))
    if DisplayServer.get_name() != "headless":
        player.play()
    # headless(테스트 러너)에서는 play()를 부르지 않는다. 출력 장치가 없어 소리가
    # 날 리 없는데, 더미 오디오 드라이버가 play()로 만든 재생 객체를 프로세스
    # 종료 때까지 풀어주지 않아 ObjectDB 누수 경고("Leaked instance:
    # AudioStreamPlaybackWAV", "Resource still in use: swat.wav")가 뜬다.
    # 재생기 자체는 만들고 풀도 그대로 돌므로, 수명 기반 회수는 그대로 검증된다.
    _players.append({"player": player, "left": player.stream.get_length() + LIFETIME_MARGIN})
    # 시그널은 재생과 별개로 낸다. headless에는 오디오 장치가 없어 실제 소리는
    # 나지 않으므로, 테스트가 검증하는 것은 이 신호다.
    sfx_played.emit(name)


func _process(delta: float) -> void:
    _tick(delta)


# 수명을 깎고 만료된 재생기를 회수한다. finished 가 늦거나 없을 수 있으므로
# (오디오 장치 없는 환경), 이 타이머가 그 환경의 유일한 회수 경로다.
func _tick(delta: float) -> void:
    var alive: Array = []
    for entry in _players:
        var p = entry["player"]
        entry["left"] = float(entry["left"]) - delta
        # 풀린 인스턴스는 그냥 버린다. 여기서 어떤 메서드도 부르면 "previously
        # freed instance" 오류가 난다.
        if p == null or not is_instance_valid(p):
            continue
        if float(entry["left"]) <= 0.0:
            _release(p)
        else:
            alive.append(entry)
    _players = alive


func _release_oldest() -> void:
    while _players.size() >= MAX_PLAYERS:
        var oldest = _players.pop_front()
        if oldest != null and oldest.has("player"):
            _release(oldest["player"])


func _release(player: Object) -> void:
    if player == null or not is_instance_valid(player):
        return
    (player as AudioStreamPlayer).queue_free()


# 오토로드는 프로세스와 함께 끝나므로, 수명이 남은 재생기도 여기서 푼다.
# 소리가 울리는 도중에 게임을 끄면(오디오 장치가 있는 환경) 풀에 재생기가 남는데,
# 이 정리가 없으면 그 노드가 종료까지 살아남는다.
#
# queue_free() 가 아니라 free()를 쓰는 이유: 프로세스 종료 중에는 지연 해제
# (queue_free)가 처리되지 않는다. _exit_tree 에 도달했을 때 풀에 남아 있던
# 재생기를 queue_free()로 해제했음에도 그대로 남는 것을 확인했다.
func _exit_tree() -> void:
    for entry in _players:
        if entry != null and entry.has("player"):
            var p = entry["player"]
            if p != null and is_instance_valid(p):
                p.free()
    _players.clear()
