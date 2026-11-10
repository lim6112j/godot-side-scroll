class_name Main
extends Node

# 게임 흐름 (설계 9.1). 타이틀 → 레벨 1 → … → 레벨 5 → 완료 화면. "레벨을 어떻게
# 조립하는지"는 Level.setup()이, "진행 상태를 어디에 두는지"는 GameState 오토로드가
# 결정하므로, 이 스크립트는 화면 전환 시점만 정한다.
#
# 사망은 여기서 아무것도 하지 않는다: 씬을 리로드하지 않고 level.tscn 내부에서
# 플레이어 위치·체력·파괴된 오브젝트만 리셋한다 (설계 5.5·9.1). 그 리셋은
# Level._on_player_died() → BabySeal.respawn_at()이 같은 신호에서 수행하므로,
# 이 흐름에 게임오버 화면을 띄우는 경로는 없다.

const LEVEL_SCENE := preload("res://scenes/level/level.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause.tscn")

var _screens: UiScreens = null
var _pause_overlay: PauseOverlay = null
# 일시정지·재시도 키의 상승 에지. 점프·꼬리치기와 같은 폴링 이유로
# is_action_just_pressed() 를 쓰지 않는다 (seal_baby.gd 주석: 한 물리 틱 늦게
# 보고해 그 틱의 누름을 놓친다).
var _pause_was_down: bool = false
var _retry_was_down: bool = false


func _ready() -> void:
    _screens = UiScreens.new(self)
    _screens.show_title()
    # 오토로드의 신호를 여기서 받는다. 하트·물고기·현재 레벨 인덱스가 모두
    # GameState에 있으므로, 구독자(이 흐름과 HUD)가 같은 곳에서 찾는다.
    GameState.level_completed.connect(_on_level_completed)
    GameState.player_died.connect(_on_player_died)


# 일시정지·재시도 입력 (설계 10장). 키 폴링은 점프·꼬리치기와 같은 상승 에지
# 규칙을 쓴다.
#
# 이 폴링은 Main 이 PAUSABLE 이라 트리가 멈추면 같이 멈춘다. 그래서 일시정지
# 중에는 아무 키도 읽지 않고(재시도가 걸려도 무시된다), 닫기는 PauseOverlay
# (PROCESS_MODE_ALWAYS) 가 담당한다.
func _physics_process(_delta: float) -> void:
    var pause_down := Input.is_action_pressed("pause")
    if pause_down and not _pause_was_down:
        pause_game()
    _pause_was_down = pause_down

    var retry_down := Input.is_action_pressed("retry")
    if retry_down and not _retry_was_down:
        retry_level()
    _retry_was_down = retry_down


# 일시정지. 이미 걸려 있으면 오버레이를 하나 더 띄우지 않는다.
func pause_game() -> void:
    if get_tree().paused:
        return
    get_tree().paused = true
    _pause_overlay = PAUSE_SCENE.instantiate() as PauseOverlay
    add_child(_pause_overlay)


# 계속. 오버레이가 자기 자신을 떼어 내므로 여기서는 트리 상태만 푼다.
func resume_game() -> void:
    get_tree().paused = false
    _pause_overlay = null


# 오버레이가 트리에 남은 채로 이 흐름이 레벨을 갈아끼우면 뒤 레벨의 일시정지
# 상태가 꼬인다. 흐름 전환 전에 항상 치운다.
func _clear_pause_overlay() -> void:
    if _pause_overlay == null:
        return
    if _pause_overlay.is_inside_tree():
        remove_child(_pause_overlay)
    _pause_overlay.queue_free()
    _pause_overlay = null
    get_tree().paused = false


# GameState는 오토로드라 씬보다 오래 산다. 연결을 남겨 두면 해제된 Main의
# 핸들러가 뒤따르는 스위트의 사망·클리어 신호를 받는 경로가 된다.
func _exit_tree() -> void:
    var completed := Callable(self, "_on_level_completed")
    if GameState.level_completed.is_connected(completed):
        GameState.level_completed.disconnect(completed)
    var died := Callable(self, "_on_player_died")
    if GameState.player_died.is_connected(died):
        GameState.player_died.disconnect(died)


func start_game() -> void:
    GameState.current_level_index = 1
    goto_level(1)


# 레벨을 교체한다. 옛 레벨은 트리에서 바로 떼어 해제 큐에 넣는다:
# queue_free()만 하면 프레임 말까지 트리에 남아 find_child("Hud")가 옛 HUD를
# 집어온다.
#
# 레벨별 상태(하트·물고기·레벨 인덱스)의 단일 소유자는 Level.setup() 이다. 여기서
# reset_for_level() 을 부르면 옛 레벨이 아직 트리에 붙어 있는 동안
# hearts_changed 가 곧 떼어 낼 HUD 에게 한 번 더 나가므로, 리셋은 setup() 에
# 맡긴다.
func goto_level(index: int) -> void:
    _clear_pause_overlay()
    GameState.current_level_index = index
    _screens.hide_all()
    var old := find_child("Level", true, false)
    if old != null:
        remove_child(old)
        old.queue_free()
    var level := LEVEL_SCENE.instantiate() as Node
    level.name = "Level"
    add_child(level)
    var data := LevelRegistry.get_level(index) as LevelData
    var seal: BabySeal = level.call("setup", data)
    # HUD 배선은 setup() 반환 이후에 한다. fish_total은 level.setup() 안에서
    # 설정되므로, _ready()에서 시드하면 fish_total=0을 읽는다.
    var hud := level.find_child("Hud", true, false) as Hud
    if hud != null:
        hud.set_level(index)
        hud.set_fish(GameState.fish_collected, GameState.fish_total)
    # 부활 배선. 리스폰은 씬을 리로드하지 않고 같은 인스턴스를 제자리로
    # 되돌리므로(seal_baby.gd respawn_at 주석), 부활 직후의 파생 상태는
    # 여기서 다시 맞춘다.
    if seal != null:
        seal.respawned.connect(_on_seal_respawned.bind(seal))


# 부활 직후 처리 (체크포인트). 두 가지를 고친다:
#  1. 빙산이 부활 지점을 캠핑하면 닿자마자 하트가 깎여 죽음이 무한 반복하므로,
#     레벨에 빙산이 있으면 물범 뒤로 재배치한다.
#  2. reset_for_level() 은 fish_changed 를 내지 않으므로, HUD 에 남은
#     "물고기 N / total" 을 0 / total 로 바로잡는다.
func _on_seal_respawned(seal: BabySeal) -> void:
    var level := find_child("Level", true, false) as Node
    if level == null:
        return
    var berg := level.find_child("Iceberg", true, false) as Iceberg
    if berg != null:
        berg.reposition_behind(seal.global_position.x)
    var hud := level.find_child("Hud", true, false) as Hud
    if hud != null:
        hud.set_fish(GameState.fish_collected, GameState.fish_total)


# 레벨 완료 화면의 "처음부터 다시". 마지막 레벨까지 끝났으면 1로 감아 새 게임을
# 시작한다. 완료 화면은 마지막 레벨 이후에만 뜨므로 실제로는 이 경로를 탄다.
func next_level() -> void:
    var next: int = GameState.current_level_index + 1
    if next > LevelRegistry.level_count():
        next = 1
    goto_level(next)


func show_level_complete() -> void:
    _screens.show_level_complete()


func show_game_over() -> void:
    # 사망 신호는 seal_baby.gd의 is_dead() 가드로 한 번만 나가지만, 두 번
    # 나가면 화면이 겹쳐 쌓인다. 이미 게임오버 화면이면 다시 띄우지 않는다.
    if _screens.is_showing("GameOver"):
        return
    _screens.show_game_over()


func retry_level() -> void:
    goto_level(GameState.current_level_index)


func _on_level_completed(level_index: int) -> void:
    if level_index >= LevelRegistry.level_count():
        show_level_complete()
    else:
        goto_level(level_index + 1)


func _on_player_died() -> void:
    # 사망은 씬 전환 없이 level.tscn 내부에서 상태만 리셋한다 (설계 5.5·9.1).
    # 체크포인트 부활은 Level._on_player_died() → BabySeal.respawn_at()이
    # 같은 신호에서 처리하므로, 이 흐름은 죽음에 아무것도 하지 않는다.
    #
    # 게임오버 화면을 여기서 띄우면 안 된다: 그 오버레이의 유일한 버튼
    # ("다시 시도")은 retry_level()을 불러 레벨을 처음부터 다시 조립하므로,
    # 컨트롤러가 시킨 체크포인트 부활이 사용자에게 보이지 않게 된다.
    # 설계에 게임오버 모달 개념은 없고, 부활 자체가 사망의 메커니즘이다.
    pass
