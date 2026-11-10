class_name LevelData
extends Resource

# 레벨 하나의 난이도 파라미터 (설계 8장). level_generator.gd 가 이 값을 받아
# 지형·적·위험을 배치하므로, 난이도 곡선을 수정하려면 이 데이터만 고칩니다.
# 시드가 고정이므로 같은 레벨은 항상 같은 모양으로 생성됩니다.

# 평면 점프 최대 도달 거리 (설계 8.3: 0.71초 × 130px/s = 92px).
# flat_max_gap_px 는 반드시 이 값 이하여야 합니다.
const MAX_FLAT_GAP := 92.0

@export var level_index: int
@export var length_px: float
@export var flat_max_gap_px: float         # 점프만으로 건너는 틈. 반드시 92 이하
@export var recoil_max_gap_px: float       # 반동/고저차가 필요한 최대 틈. 0 = 없음
@export var enemy_density: float           # 1000px 당 개수
@export var hazard_count: int
@export var checkpoint_count: int
@export var enemy_mix: Array[String]       # ["crab"] → ["crab","crab","seagull"]
@export var allows_thin_ice: bool
@export var allows_icicle: bool
@export var allows_water: bool
@export var has_time_pressure: bool
@export var swat_wall_count: int           # 장치 A: 꼬리치기로 부숴야 하는 얼음 벽 수
@export var recoil_gap_count: int          # 장치 B: 반동 없이는 못 건너는 틈 수
@export var seed_value: int                # 고정 시드 → 재현 가능
