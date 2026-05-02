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
	print("Map:", map)
	print("Units container:", map.units_container)

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
	
	unit.unit_manager = self
	unit.map = map
	
	map.place_unit(unit, pos)
	
	# 🔥 GARANTE QUE NÃO TEM PAI
	if unit.get_parent():
		unit.get_parent().remove_child(unit)
	
	# 🔥 ADICIONA NO LUGAR CORRETO
	map.units_container.add_child(unit)
	
	units.append(unit)
	
	print("Spawnando unidade em:", pos, "facção:", faction)
	print("Units no container agora:", map.units_container.get_child_count())
	
	return unit


func remove_unit(unit: HeroUnit) -> void:
	units.erase(unit)

# =========================
# 🔥 LIMPEZA CENTRAL (ESSENCIAL)
# =========================
func cleanup_units() -> void:
	var valid_units: Array[HeroUnit] = []
	
	for u in units:
		if is_instance_valid(u) and u.is_alive():
			valid_units.append(u)
	
	units = valid_units

# =========================
# CONSULTAS
# =========================
func get_unit_at(grid_pos: Vector2i) -> HeroUnit:
	cleanup_units()
	
	for u in units:
		if u.grid_pos == grid_pos:
			return u
	
	return null


func get_units_by_faction(faction: Faction.Type) -> Array[HeroUnit]:
	cleanup_units()
	
	var result: Array[HeroUnit] = []
	
	for u in units:
		if u.faction == faction:
			result.append(u)
	
	return result


func get_occupied_tiles() -> Array[Vector2i]:
	cleanup_units()
	
	var tiles: Array[Vector2i] = []
	
	for u in units:
		tiles.append(u.grid_pos)
	
	return tiles

# =========================
# TURNO
# =========================
func reset_units_turn(faction: Faction.Type) -> void:
	cleanup_units()
	
	for u in units:
		if u.faction == faction:
			u.reset_turn()


func all_player_units_acted() -> bool:
	cleanup_units()
	
	var allies: Array[HeroUnit] = get_units_by_faction(Faction.Type.ALLY)
	
	if allies.is_empty():
		return true # evita travar turno
	
	for u in allies:
		if not u.has_acted:
			return false
	
	return true
