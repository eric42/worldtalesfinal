extends Node
class_name UnitManager

# =========================
# DEPENDÊNCIAS
# =========================
@export var battle_map_path: NodePath
@export var hero_scene: PackedScene

@onready var map: BattleMap = get_node_or_null(battle_map_path)

# =========================
# REGISTRO DE UNIDADES
# =========================
var units: Array[HeroUnit] = []

# =========================
# GODOT
# =========================
func _ready() -> void:
	print("UnitManager:")
	print(" map =", map)
	print(" hero_scene =", hero_scene)

	assert(map != null)
	assert(hero_scene != null)

	print("UnitManager pronto")

# =========================
# SPAWN / REMOVE
# =========================
func spawn_unit(grid_pos: Vector2i, faction: String) -> HeroUnit:
	var unit: HeroUnit = hero_scene.instantiate()

	unit.map = map
	unit.grid_pos = grid_pos
	unit.faction = faction
	unit.position = Vector2(grid_pos) * map.TILE_SIZE

	map.units_container.add_child(unit)
	units.append(unit)

	return unit

func remove_unit(unit: HeroUnit) -> void:
	if unit in units:
		units.erase(unit)
	unit.queue_free()

# =========================
# CONSULTAS
# =========================
func get_unit_at(grid_pos: Vector2i) -> HeroUnit:
	for u in units:
		if u.grid_pos == grid_pos and u.is_alive():
			return u
	return null

func get_units_by_faction(faction: String) -> Array[HeroUnit]:
	var result: Array[HeroUnit] = []
	for u in units:
		if u.faction == faction and u.is_alive():
			result.append(u)
	return result

func get_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for u in units:
		if u.is_alive():
			tiles.append(u.grid_pos)
	return tiles

# =========================
# TURNO
# =========================
func reset_units_turn(faction: String) -> void:
	for u in units:
		if u.faction == faction:
			u.reset_turn()

func all_player_units_acted() -> bool:
	for u in units:
		if u.faction == "ally" and not u.has_acted:
			return false
	return true
