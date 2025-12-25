extends Node2D
class_name BattleMap

const TILE_SIZE := 64
const WIDTH := 11
const HEIGHT := 11

@onready var units_container: Node2D = $Units
@onready var hero_scene: PackedScene = preload("res://units/HeroUnit.tscn")

var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_unit: HeroUnit = null

var units: Array = []
var reachable_tiles: Array[Vector2i] = []

var astar := AStarGrid2D.new()

var is_player_turn := true

var attack_mode := false
var attack_tiles: Array[Vector2i] = []

func _ready():
	print("BattleMap pronta")
	queue_redraw()
	_setup_astar()

func _draw():
	for x in range(WIDTH):
		for y in range(HEIGHT):
			draw_rect(
				Rect2(
					Vector2(x, y) * TILE_SIZE,
					Vector2(TILE_SIZE, TILE_SIZE)
				),
				Color(1, 1, 1, 0.15),
				false
			)
	
	if hovered_tile.x >= 0 and hovered_tile.y >= 0:
		draw_rect(
			Rect2(
				Vector2(hovered_tile) * TILE_SIZE,
				Vector2(TILE_SIZE, TILE_SIZE)
			),
			Color(1, 1, 0, 0.25),
			true
		)
	
	if selected_unit:
		for tile in reachable_tiles:
			draw_rect(
				Rect2(
					Vector2(tile) * TILE_SIZE,
					Vector2(TILE_SIZE, TILE_SIZE)
				),
				Color(0.3, 0.6, 1, 0.25),
				true
			)
	
	if selected_unit:
		draw_rect(
			Rect2(
				Vector2(selected_unit.grid_pos) * TILE_SIZE,
				Vector2(TILE_SIZE, TILE_SIZE)
			),
			Color(0, 1, 0, .35),
			true
		)
	
	for tile in attack_tiles:
		draw_rect(
			Rect2(tile * TILE_SIZE,
			Vector2(TILE_SIZE, TILE_SIZE)
			),
			Color(1, 0, 0, 0.4),
			true
		)

func _input(event):
	if not is_player_turn:
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		if selected_unit and not selected_unit.has_acted:
			attack_mode = true
			_compute_attack_tiles(selected_unit)
			queue_redraw()
		return
	
	if attack_mode and event is InputEventMouseButton and event.pressed:
			var grid = _mouse_to_grid(event.position)
			var target = _get_unit_at(grid)
			
			if target and grid in attack_tiles and target.faction != selected_unit.faction:
				_execute_attack(selected_unit, target)
			else:
				attack_mode = false
				attack_tiles.clear()
				_clear_selection()
			
			return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = get_local_mouse_position()
		var grid = Vector2i(
			int(mouse_pos.x / TILE_SIZE),
			(mouse_pos.y / TILE_SIZE)
		)
		
		hovered_tile = grid
		
		var clicked_unit: HeroUnit = _get_unit_at(grid)
			
		if clicked_unit and clicked_unit.faction == "ally":
			if clicked_unit.has_acted:
				return
			
			selected_unit = clicked_unit
			_compute_reachable_tiles(selected_unit)
		elif selected_unit and grid in reachable_tiles:

			var path = _get_path(selected_unit.grid_pos, grid, selected_unit)
			
			if path.size() > 0:
				_move_unit_along_path(selected_unit, path)

			reachable_tiles.clear()
			print("Unidade movida para:", grid)
			
			if all_player_units_acted():
				get_parent().end_player_turn()
		else:
			selected_unit = null
			print("Seleção limpa")
		
		queue_redraw()

func _get_unit_at(grid_pos: Vector2i) -> HeroUnit:
	for u in units:
		if u.grid_pos == grid_pos:
			return u
	return null

func _compute_reachable_tiles(unit):
	reachable_tiles.clear()
	
	_update_astar_blocked(unit)
	
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile := Vector2i(x, y)
			
			if tile == unit.grid_pos:
				continue
			
			if astar.is_point_solid(tile):
				continue
			var cost := _get_path_cost(unit.grid_pos, tile, unit)
			
			if cost <= unit.move_range:
				reachable_tiles.append(tile)

func _is_tile_occupied(grid_pos: Vector2i) -> bool:
	for u in units:
		if u.grid_pos == grid_pos:
			return true
	return false

func spawn_unit(scene: PackedScene, grid_pos: Vector2i, faction: String):
	var u = scene.instantiate()
	
	u.map = self
	u.grid_pos = grid_pos
	u.faction = faction
	u.position = Vector2(grid_pos) * TILE_SIZE
	
	units_container.add_child(u)
	units.append(u)
	print("Spawnando unidade em", grid_pos)

func _setup_astar():
	astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	astar.cell_size = Vector2i(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()

func _update_astar_blocked(unit_to_ignore):
	astar.update()
	
	for u in units:
		if u == unit_to_ignore:
			continue
		astar.set_point_solid(u.grid_pos, true)

func _get_path(from: Vector2i, to: Vector2i, unit):
	_update_astar_blocked(unit)
	
	if astar.is_point_solid(to):
		return []
	
	var path: Array[Vector2i] = astar.get_id_path(from, to)
	return path

func _move_unit_along_path(unit, path: Array[Vector2i]):
	if path.size() <= 1:
		return
	
	path.remove_at(0)
	
	var tween := create_tween()
	
	for tile in path:
		tween.tween_property(
			unit,
			"position",
			Vector2(tile) * TILE_SIZE,
			0.15
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		tween.tween_callback(func():
			unit.grid_pos = tile
			)
	tween.finished.connect(func():
		unit.has_acted = true
		_clear_selection()
		
		if all_player_units_acted():
			get_parent().end_player_turn()
	)

func _get_path_cost(from: Vector2i, to: Vector2i, unit) -> int:
	var path = _get_path(from, to, unit)
	if path.is_empty():
		return INF
	return path.size() - 1

func _clear_selection():
	selected_unit = null
	reachable_tiles.clear()
	queue_redraw()

func all_player_units_acted() -> bool:
	for u in units:
		if u.faction == "ally" and not u.has_acted:
			return false
	return true

func _compute_attack_tiles(unit):
	attack_tiles.clear()
	
	var dirs = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]
	
	for d in dirs:
		var tile = unit.grid_pos + d
		if _is_inside_map(tile):
			attack_tiles.append(tile)
		

func _execute_attack(attacker, defender):
	var damage = CombatResolver.calculate_damage(
		attacker,
		defender,
		CombatResolver.AttackType.PHYSICAL,
		CombatResolver.Modifier.NEUTRAL,
		CombatResolver.Modifier.NEUTRAL
	)
	
	defender.hp -= damage
	print("Dano Causado:", damage, "HP restante:", defender.hp)
	
	if defender.hp <= 0:
		_kill_unit(defender)
	
	attacker.has_acted = true
	attack_mode = false
	attack_tiles.clear()
	_clear_selection()
	
	if all_player_units_acted():
		get_parent().end_player_turn()
	
func _kill_unit(unit):
	units.erase(unit)
	unit.queue_free()

func _is_inside_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < WIDTH and tile.y < HEIGHT

func _mouse_to_grid(mouse_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(mouse_pos.x / TILE_SIZE),
		int(mouse_pos.y / TILE_SIZE)
	)
