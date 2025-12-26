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
	set_process_unhandled_input(true)
	print("BattleMap pronta")
	_setup_astar()
	queue_redraw()

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

func _input(event: InputEvent) -> void:
	# Jogador só pode agir no próprio turno
	if not is_player_turn:
		return

	# =====================================
	# MODO ATAQUE
	# =====================================
	if attack_mode and event is InputEventMouseButton and event.pressed:
		var grid: Vector2i = _mouse_to_grid(get_local_mouse_position())
		var target: HeroUnit = _get_unit_at(grid)

		if (
			selected_unit
			and target
			and grid in attack_tiles
			and target.faction != selected_unit.faction
		):
			# Ataque válido
			_execute_attack(selected_unit, target)
		else:
			# Cancelou ataque → encerra ação (Wait implícito)
			_finish_player_action(selected_unit)

		queue_redraw()
		return

	# =====================================
	# TECLA DE ATAQUE (A)
	# =====================================
	if event is InputEventKey and event.pressed and event.keycode == KEY_A:
		if selected_unit and not selected_unit.has_acted:
			attack_mode = true
			reachable_tiles.clear()
			_compute_attack_tiles(selected_unit)
			queue_redraw()
		return

	# =====================================
	# CLIQUE ESQUERDO (SELEÇÃO / MOVIMENTO)
	# =====================================
	if event is InputEventMouseButton \
	and event.pressed \
	and event.button_index == MOUSE_BUTTON_LEFT:

		var mouse_pos: Vector2 = get_local_mouse_position()
		var grid: Vector2i = _mouse_to_grid(mouse_pos)

		print("DEBUG CLICK grid:", grid)

		var clicked_unit: HeroUnit = _get_unit_at(grid)

		# ---------------------------------
		# SELECIONAR UNIDADE ALIADA
		# ---------------------------------
		if clicked_unit and clicked_unit.faction == "ally":
			if clicked_unit.has_acted:
				return

			print("DEBUG UNIT:", clicked_unit.grid_pos)

			selected_unit = clicked_unit
			attack_mode = false
			attack_tiles.clear()
			_compute_reachable_tiles(selected_unit)
			queue_redraw()
			return

		# ---------------------------------
		# MOVER UNIDADE SELECIONADA
		# ---------------------------------
		if selected_unit and grid in reachable_tiles:
			var path: Array[Vector2i] = _get_path(
				selected_unit.grid_pos,
				grid,
				selected_unit
			)

			if path.size() > 0:
				var tween: Tween = _move_unit_along_path(selected_unit, path)
				if tween:
					await tween.finished

			# Movimento encerra a ação
			_finish_player_action(selected_unit)
			queue_redraw()
			return

		# ---------------------------------
		# CLIQUE INVÁLIDO → WAIT IMPLÍCITO
		# ---------------------------------
		if selected_unit:
			_finish_player_action(selected_unit)
			queue_redraw()
			return

		# Nada selecionado → apenas limpa
		_clear_selection()
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
	for x in range(WIDTH):
		for y in range(HEIGHT):
			astar.set_point_solid(Vector2i(x, y), false)
	
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

func _move_unit_along_path(unit: HeroUnit, path: Array[Vector2i]) -> Tween:
	if path.size() <= 1:
		return null

	# remove tile inicial (posição atual)
	path.remove_at(0)

	var tween := create_tween()

	for tile in path:
		var target_pos := Vector2(tile) * TILE_SIZE

		tween.tween_property(
			unit,
			"position",
			target_pos,
			0.15
		)

		# 🔥 ATUALIZA O GRID A CADA TILE
		tween.tween_callback(func():
			unit.grid_pos = tile
		)

	return tween


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
	print("Atacante Causou:", damage, "HP defensor:", defender.hp)
	
	if defender.hp <= 0:
		_kill_unit(defender)
		_end_attack(attacker)
		return
	
	if _is_adjacent(attacker.grid_pos, defender.grid_pos):
		var counter_damage = CombatResolver.calculate_damage(
			defender,
			attacker,
			CombatResolver.AttackType.PHYSICAL,
			CombatResolver.Modifier.NEUTRAL,
			CombatResolver.Modifier.NEUTRAL
		)
		
		attacker.hp -= counter_damage
		print("Contra-ataque causou", counter_damage, "-> HP atacante:", attacker.hp)
		
		if attacker.hp <= 0:
			_kill_unit(attacker)
			return
		
	_end_attack(attacker)

func _end_attack(attacker: HeroUnit):
	attacker.has_acted = true
	attack_mode = false
	attack_tiles.clear()
	_clear_selection()


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

func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func _process_enemy_turn():
	print("IA inimiga processando...")
	
	for enemy in units:
		if enemy.faction != "enemy":
			continue
		if enemy.has_acted:
			continue
		
		await _enemy_take_action(enemy)
	

func _get_closest_ally(from: HeroUnit) -> HeroUnit:
	var closest: HeroUnit = null
	var best_dist: int = 999999
	
	for u in units:
		if u.faction != "ally":
			continue
		
		var dist: int = abs(u.grid_pos.x - from.grid_pos.x) + abs(u.grid_pos.y - from.grid_pos.y)
		if dist < best_dist:
			best_dist = dist
			closest = u
		
	return closest

func _enemy_take_action(enemy: HeroUnit) -> void:
	if enemy.has_acted:
		return
	
	var target: HeroUnit = _get_closest_ally(enemy)
	if not target:
		enemy.has_acted = true
		return
	
	if _is_adjacent(enemy.grid_pos, target.grid_pos):
		_execute_attack(enemy, target)
		return
	
	var destination: Vector2i = _get_best_adjacent_tile(enemy, target)
	if destination == Vector2i(-1, -1):
		enemy.has_acted = true
		return
	
	var path: Array[Vector2i] = _get_path(enemy.grid_pos, destination, enemy)
	if path.size() <= 1:
		enemy.has_acted = true
		return
	
	var steps: int = min(enemy.move_range, path.size() - 1)
	var final_path: Array[Vector2i] = []
	
	for i in range(steps + 1):
		final_path.append(path[i])
	
	var tween: Tween = _move_unit_along_path(enemy, final_path)
	
	if tween:
		await tween.finished
		
		if _is_adjacent(enemy.grid_pos, target.grid_pos) and target.is_alive():
			_execute_attack(enemy, target)
			return
		
		enemy.has_acted = true

func start_enemy_turn():
	is_player_turn = false
	
	for u in units:
		if u.faction == "enemy":
			u.reset_turn()
	
	await  _process_enemy_turn()

func start_player_turn():
	is_player_turn = true
	attack_mode = false
	attack_tiles.clear()
	_clear_selection()
	
	for u in units:
		if u.faction == "ally":
			u.reset_turn()
	
	queue_redraw()

func _get_best_adjacent_tile(enemy: HeroUnit, target: HeroUnit) ->  Vector2i:
	var best_tile := Vector2i(-1, -1)
	var best_cost := INF
	
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var tile : Vector2i = target.grid_pos + d
		
		if not _is_inside_map(tile):
			continue
		if _is_tile_occupied(tile):
			continue
		
		var cost := _get_path_cost(enemy.grid_pos, tile, enemy)
		if cost < best_cost:
			best_cost = cost
			best_tile = tile
		
	return best_tile

func _finish_player_action(unit: HeroUnit) -> void:
	if not unit:
		return

	unit.has_acted = true
	attack_mode = false
	attack_tiles.clear()
	_clear_selection()

	if all_player_units_acted():
		get_parent().end_player_turn()
