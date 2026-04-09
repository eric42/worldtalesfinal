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
func spawn_unit(pos: Vector2i, faction: Faction.Type) -> HeroUnit:
	assert(hero_scene != null)
	
	if pos in get_occupied_tiles():
		push_error("Tile ocupado: " + str(pos))
		return null
		
	var unit: HeroUnit = hero_scene.instantiate()
	
	unit.faction = faction
	unit.has_acted = false
	
	unit.unit_manager = self   # ESSENCIAL
	unit.map = map             # MUITO IMPORTANTE
	
	map.place_unit(unit, pos)
	
	add_child(unit)
	units.append(unit)
	
	print("HeroUnit pronta | grid =", pos, "| faction =", faction)
	
	return unit

func remove_unit(unit):
	units.erase(unit)

# =========================
# CONSULTAS
# =========================
func get_unit_at(grid_pos: Vector2i) -> HeroUnit:
	for u in units:
		if u.grid_pos == grid_pos and u.is_alive():
			return u
	return null

func get_units_by_faction(faction: Faction.Type) -> Array[HeroUnit]:
	var result: Array[HeroUnit] = []
	
	for u: HeroUnit in units:
		if u.faction == faction and u.is_alive():
			result.append(u)
	return result

func get_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var valid_units: Array[HeroUnit] = []
	
	for u in units:
		if is_instance_valid(u) and u.is_alive():
			tiles.append(u.grid_pos)
			valid_units.append(u)
			
	units = valid_units
	
	return tiles

# =========================
# TURNO
# =========================
func reset_units_turn(faction: Faction.Type) -> void:
	for u: HeroUnit in units:
		if u.faction == faction:
			u.reset_turn()

func all_player_units_acted() -> bool:
	return get_units_by_faction(Faction.Type.ALLY).all(
		func(u: HeroUnit) -> bool:
			return u.has_acted
	)
