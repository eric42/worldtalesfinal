extends Node2D
class_name HeroUnit

# =========================
# REFERÊNCIAS
# =========================
var map: BattleMap = null
var grid_pos: Vector2i
var faction: String = "ally" # "ally" | "enemy"

# =========================
# STATS (BASE)
# =========================
@export var max_hp: int = 20
@export var atk: int = 10
@export var def: int = 5
@export var res: int = 3
@export var spd: int = 5
@export var move_range: int = 3

# =========================
# ESTADO
# =========================
var hp: int
var has_acted: bool = false

# =========================
# GODOT
# =========================
func _ready() -> void:
	hp = max_hp
	_sync_world_position()
	print("HeroUnit pronta | grid =", grid_pos, "| faction =", faction)

# =========================
# TURNO
# =========================
func reset_turn() -> void:
	has_acted = false

# =========================
# VIDA
# =========================
func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)

# =========================
# POSIÇÃO (ÚNICA FONTE DA VERDADE)
# =========================
func set_grid_pos(new_pos: Vector2i) -> void:
	grid_pos = new_pos
	_sync_world_position()

func _sync_world_position() -> void:
	if map != null:
		position = Vector2(grid_pos) * map.TILE_SIZE
