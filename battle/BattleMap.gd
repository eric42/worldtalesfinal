extends Node2D
class_name BattleMap

# =========================
# CONFIGURAÇÃO DO MAPA
# =========================
const WIDTH: int = 11
const HEIGHT: int = 11

@export var tile_size: int = 64

# =========================
# NODES
# =========================
@onready var units_container: Node2D = $Units

# =========================
# VISUAL
# =========================
var hovered_tile: Vector2i = Vector2i(-1, -1)
var reachable_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []

# =========================
# PATHFINDING
# =========================
var astar: AStarGrid2D = AStarGrid2D.new()
var preview_path: Array[Vector2i] = []
var hover_attack_tiles: Array[Vector2i] = []

# =========================
# GODOT
# =========================
func _ready() -> void:
	_setup_astar()
	queue_redraw()
	print("BattleMap pronta")

func _draw() -> void:
	# GRID
	for x in range(WIDTH):
		for y in range(HEIGHT):
			draw_rect(
				Rect2(Vector2(x, y) * tile_size, Vector2(tile_size, tile_size)),
				Color(1, 1, 1, 0.15),
				false
			)

	# HOVER
	if hovered_tile.x >= 0:
		draw_rect(
			Rect2(Vector2(hovered_tile) * tile_size, Vector2(tile_size, tile_size)),
			Color(1, 1, 0, 0.25),
			true
		)

	# MOVIMENTO
	for tile in reachable_tiles:
		draw_rect(
			Rect2(Vector2(tile) * tile_size, Vector2(tile_size, tile_size)),
			Color(0.3, 0.6, 1, 0.25),
			true
		)

	#PATH PREVIEW
	for tile in preview_path:
		draw_rect(
			Rect2(Vector2(tile) * tile_size, Vector2(tile_size,  tile_size)),
			Color(0.2, 1.0, 1.0, 0.35),
			true
		)

	# ATAQUE
	for tile in attack_tiles:
		draw_rect(
			Rect2(Vector2(tile) * tile_size, Vector2(tile_size, tile_size)),
			Color(1, 0, 0, 0.35),
			true
		)
		print("DRAW CALL | attack_tiles:", attack_tiles)

	#HOVER ATTACK
	for tile in hover_attack_tiles:
		draw_rect(
			Rect2(Vector2(tile) * tile_size, Vector2(tile_size, tile_size)),
			Color(1, 0.5, 0, 0.45),
			true
		)

# =========================
# GRID
# =========================
func grid_to_world(grid: Vector2i) -> Vector2:
	return Vector2(grid.x * tile_size, grid.y * tile_size)

func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / tile_size),
		int(pos.y / tile_size)
	)

func is_inside_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < WIDTH and tile.y < HEIGHT

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

# =========================
# VISUAL API
# =========================
func set_hovered_tile(tile: Vector2i) -> void:
	hovered_tile = tile
	queue_redraw()

func clear_selection() -> void:
	reachable_tiles.clear()
	attack_tiles.clear()

	preview_path.clear()
	hover_attack_tiles.clear()

	queue_redraw()

func show_reachable_tiles(tiles: Array[Vector2i]) -> void:
	reachable_tiles = tiles
	queue_redraw()

func show_attack_tiles(tiles: Array[Vector2i]) -> void:
	attack_tiles = tiles
	print("Tiles de ataque enviados:", tiles) # DEBUG
	queue_redraw()

func is_tile_reachable(tile: Vector2i) -> bool:
	return tile in reachable_tiles

# =========================
# PATHFINDING
# =========================
func _setup_astar() -> void:
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2i.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

func get_grid_path(
	from: Vector2i,
	to: Vector2i,
	unit_to_ignore: HeroUnit,
	blocked_positions: Array[Vector2i]
) -> Array[Vector2i]:

	for x in range(WIDTH):
		for y in range(HEIGHT):
			astar.set_point_solid(Vector2i(x, y), false)

	for pos in blocked_positions:
		if pos != unit_to_ignore.grid_pos:
			astar.set_point_solid(pos, true)

	if astar.is_point_solid(to):
		return []

	return astar.get_id_path(from, to)

# =========================
# MOVIMENTO
# =========================
func move_unit_along_path(
	unit: HeroUnit,
	path: Array[Vector2i]
) -> Tween:

	if path.size() <= 1:
		return null

	var tween: Tween = create_tween()

	for tile in path.slice(1):
		var target_pos: Vector2 = grid_to_world(tile)
		tween.tween_property(unit, "position", target_pos, 0.15)

	tween.finished.connect(func():
		unit.set_grid_pos(path[-1])
	)

	return tween

# =========================
# COMBATE
# =========================
func execute_attack(attacker: HeroUnit, defender: HeroUnit) -> void:
	var result: Dictionary = CombatResolver.simulate_attack(attacker, defender)
	
	#=======================
	#Ataque Inicial
	#=======================
	defender.take_damage(result["damage_to_defender"])
	print("Dano no defensor:", result["damage_to_defender"])
	
	#=======================
	#Contra-ataque (SE SOBREVIVER)
	#=======================
	if defender.is_alive():
		attacker.take_damage(result["damage_to_attacker"])
		print("Contra-ataque:", result["damage_to_attacker"])
	
	#=======================
	#morte
	#=======================
	if not defender.is_alive():
		print("Defensor morreu")
		defender.queue_free()
	
	if not attacker.is_alive():
		print("Atacante morreu")
		attacker.queue_free()
	
# =========================
# MOVIMENTO RANGE
# =========================
func compute_reachable_tiles(
	unit: HeroUnit,
	blocked_positions: Array[Vector2i]
) -> Array[Vector2i]:

	var result: Array[Vector2i] = []

	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile: Vector2i = Vector2i(x, y)

			if tile == unit.grid_pos:
				continue

			var path: Array[Vector2i] = get_grid_path(
				unit.grid_pos,
				tile,
				unit,
				blocked_positions
			)

			if path.is_empty():
				continue

			var cost: int = path.size() - 1
			if cost <= unit.move_range:
				result.append(tile)

	return result

# =========================
# POSICIONAMENTO
# =========================
func place_unit(unit: HeroUnit, grid: Vector2i) -> void:
	unit.grid_pos = grid
	unit.position = grid_to_world(grid)

func compute_attack_tiles(unit: HeroUnit, reachable_tiles: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var possible_positions := reachable_tiles.duplicate()
	possible_positions.append(unit.grid_pos)

	for enemy in units_container.get_children():
		if enemy.faction == unit.faction:
			continue

		var enemy_pos: Vector2i = enemy.grid_pos

		for pos in possible_positions:
			var dist: int = grid_distance(pos, enemy_pos)

			if dist >= unit.attack_range_min and dist <= unit.attack_range_max:
				if enemy_pos not in result:
					result.append(enemy_pos)

	return result

func compute_attack_tiles_from_movement(
	unit: HeroUnit,
	reachable_tiles: Array[Vector2i]
) -> Array[Vector2i]:

	var attack_tiles: Array[Vector2i] = []

	var possible_positions = reachable_tiles.duplicate()
	possible_positions.append(unit.grid_pos)

	for other in units_container.get_children():

		if not is_instance_valid(other):
			continue

		# ignora aliados
		if other.faction == unit.faction:
			continue

		var enemy_pos: Vector2i = other.grid_pos

		for pos in possible_positions:
			var dist: int = grid_distance(pos, enemy_pos)

			if dist >= unit.attack_range_min and dist <= unit.attack_range_max:
				if enemy_pos not in attack_tiles:
					attack_tiles.append(enemy_pos)
				break

	return attack_tiles

func get_unit_at(tile: Vector2i) -> HeroUnit:
	for child in units_container.get_children():
		if child.grid_pos == tile:
			return child
	return null

func grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func compute_attack_range_area(unit: HeroUnit, reachable_tiles: Array[Vector2i]) -> Array[Vector2i]:
	
	var attack_tiles: Array[Vector2i] = []
	
	var positions = reachable_tiles.duplicate()
	positions.append(unit.grid_pos)
	
	for pos in positions:
		for x in range(-unit.attack_range_max, unit.attack_range_max + 1):
			for y in range(-unit.attack_range_max, unit.attack_range_max + 1):
				
				var target = pos + Vector2i(x, y)
				var dist = grid_distance(pos, target)
				
				if dist < unit.attack_range_min:
					continue
				if dist > unit.attack_range_max:
					continue
				
				if not is_inside_map(target):
					continue
				
				if target not in attack_tiles:
					attack_tiles.append(target)
				
	return attack_tiles

func get_attackable_units(unit: HeroUnit, attack_tiles: Array[Vector2i]) -> Array[HeroUnit]:
	
	var targets: Array[HeroUnit] = []
	
	for tile in attack_tiles:
		var u = get_unit_at(tile)
		
		if u != null and u.faction != unit.faction:
			targets.append(u)
	
	return targets

func show_preview_path(path: Array[Vector2i]) -> void:
	preview_path = path
	queue_redraw()

func show_hover_attack_tiles(tiles: Array[Vector2i]) -> void:
	hover_attack_tiles = tiles
	queue_redraw()

func clear_hover_preview() -> void:
	preview_path.clear()
	hover_attack_tiles.clear()
	queue_redraw()
