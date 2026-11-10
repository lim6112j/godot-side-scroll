# class_name을 붙이지 않는다: Godot는 오토로드 싱글톤과 같은 이름의 class_name을
# "hides an autoload singleton" 파싱 오류로 거부한다. 오토로드 이름 자체가
# GDScript의 전역 식별자이므로, class_name 없이도 GameState.hearts처럼 접근한다.
extends Node

# 진행 상태 (설계 5.3). 하트와 물고기, 현재 레벨 인덱스는 씬이 아니라 이
# 오토로드가 가지므로, 레벨을 리로드해도 플레이어 진행도가 살아남는다.

const MAX_HEARTS := 3

var hearts: int = MAX_HEARTS
var current_level_index: int = 1
var fish_collected: int = 0
var fish_total: int = 0

signal hearts_changed(new_value: int)
signal fish_changed(collected: int, total: int)
signal player_died
# 레벨 클리어 (설계 5.4). 엄마에게 도착하면 한 번 나간다. 발신 주체는 Level이고,
# 시그널만 오토로드에 두는 이유: 하트·물고기·현재 레벨 인덱스와 같은 진행 상태가
# 여기 있으므로, 구독자(HUD·다음 레벨 로더)가 같은 곳에서 모두 찾기 때문이다.
signal level_completed(level_index: int)

func lose_heart() -> void:
    hearts = maxi(0, hearts - 1)
    hearts_changed.emit(hearts)
    if hearts == 0:
        player_died.emit()


func collect_fish() -> void:
    fish_collected += 1
    fish_changed.emit(fish_collected, fish_total)


# 즉사 (설계 5.3: 게를 밟으면 사망). lose_heart()와 달리 하트를 한 번에 0으로
# 만든다. 하트가 이미 0이어도 player_died가 다시 나가지 않도록, 호출 측이
# is_dead()로 막는 것을 전제로 한다.
func die() -> void:
    hearts = 0
    hearts_changed.emit(hearts)
    player_died.emit()


func is_dead() -> bool:
    return hearts <= 0


# 리셋은 fish_changed를 내지 않는다. Level.setup()이 fish_total을 정한 뒤
# reset_for_level()을 부르므로, 여기서 시그널을 내면 HUD가 두 번째로 시드되어
# main.gd의 goto_level 배선(명시적 set_fish)이 죽은 코드가 된다. 카운터 갱신은
# collect_fish() 한 곳에서만 내고, 레벨 진입 시 점화는 흐름 소유자가 한다.
func reset_for_level() -> void:
    hearts = MAX_HEARTS
    fish_collected = 0
    hearts_changed.emit(hearts)


# 엄마에게 도착했다 (설계 5.4). 어떤 레벨에서 클리어했는지 신호에 싣는다.
#
# 도착 소리(설계 11장 "엄마 도착")도 이 한 곳에서 낸다. 발신 주체가 Level이고
# 구독자가 Main이므로, 소리를 Main의 level_completed 핸들러에 두면 "도착 사건이
# 났는데 화면 전환 담당이 없으면 소리도 안 나는" 상황이 생긴다. 레벨 클리어의
# 단일 출구는 이 함수이므로, 여기서 한 번만 내는 쪽이 도착마다 정확히 한 번
# 울린다.
func complete_level() -> void:
    SoundPlayer.play("arrive")
    level_completed.emit(current_level_index)
