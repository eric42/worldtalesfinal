extends Node2D
class_name BattleMap

# =========================
# CONFIGURAÇÃO DO MAPA
# =========================
const TILE_SIZE: int = 64
const WIDTH: int = 11
const HEIGHT: int = 11

# =========================
# NODES
# =========================
@onready var units_container: Node2D = $Units

# =========================
# VISUAL / SELEÇÃO
# =========================
var hovered_tile: Vector2i = Vector2i(-1, -1)
var reachable_tiles: Array[Vector2i] = []
var attack_tiles: Array[Vector2i] = []

# =========================
# PATHFINDING
# =========================
var astar: AStarGrid2D = AStarGrid2D.new()

# =========================
# GODOT
# =========================
func _ready() -> void:
	_setup_astar()
	queue_redraw()
	print("BattleMap pronta")

func _draw() -> void:
	# Grid
	for x in range(WIDTH):
		for y in range(HEIGHT):
			draw_rect(
				Rect2(Vector2(x, y) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
				Color(1, 1, 1, 0.15),
				false
			)

	# Hover
	if hovered_tile.x >= 0:
		draw_rect(
			Rect2(Vector2(hovered_tile) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(1, 1, 0, 0.25),
			true
		)

	# Movimento
	for tile in reachable_tiles:
		draw_rect(
			Rect2(Vector2(tile) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(0.3, 0.6, 1, 0.25),
			true
		)

	# Ataque
	for tile in attack_tiles:
		draw_rect(
			Rect2(Vector2(tile) * TILE_SIZE, Vector2(TILE_SIZE, TILE_SIZE)),
			Color(1, 0, 0, 0.35),
			true
		)

# =========================
# GRID / UTIL
# =========================
func mouse_to_grid(mouse_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(mouse_pos.x / TILE_SIZE),
		int(mouse_pos.y / TILE_SIZE)
	)

func is_inside_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < WIDTH and tile.y < HEIGHT

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

# =========================
# VISUAL (API PÚBLICA)
# =========================
func set_hovered_tile(tile: Vector2i) -> void:
	hovered_tile = tile
	queue_redraw()

func clear_selection() -> void:
	reachable_tiles.clear()
	attack_tiles.clear()
	queue_redraw()

func show_reachable_tiles(tiles: Array[Vector2i]) -> void:
	reachable_tiles = tiles
	queue_redraw()

func show_attack_tiles(tiles: Array[Vector2i]) -> void:
	attack_tiles = tiles
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

	# Limpa o grid
	for x in range(WIDTH):
		for y in range(HEIGHT):
			astar.set_point_solid(Vector2i(x, y), false)

	# Bloqueia unidades
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
		var target_pos: Vector2 = Vector2(tile) * TILE_SIZE
		tween.tween_property(unit, "position", target_pos, 0.15)

	tween.finished.connect(func():
		unit.set_grid_pos(path[-1])
	)

	return tween

# =========================
# COMBATE
# =========================
func execute_attack(attacker: HeroUnit, defender: HeroUnit) -> void:
	var damage: int = CombatResolver.calculate_damage(
		attacker,
		defender,
		CombatResolver.AttackType.PHYSICAL,
		CombatResolver.Modifier.NEUTRAL,
		CombatResolver.Modifier.NEUTRAL
	)

	defender.take_damage(damage)
	print("Dano:", damage, "HP defensor:", defender.hp)

	if not defender.is_alive():
		defender.queue_free()

# =========================
# ALCANCE DE MOVIMENTO
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
