extends Node2D
class_name InputController

@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath
@export var game_state_path: NodePath
@export var preview_ui_path: NodePath

@onready var map: BattleMap = get_node(battle_map_path)
@onready var unit_manager: UnitManager = get_node(unit_manager_path)
@onready var turn_manager: TurnManager = get_node(turn_manager_path)
@onready var game_state: GameStateManager = get_node(game_state_path)
@onready var preview_ui: CombatPreviewUI = get_node(preview_ui_path)

var selected_unit: HeroUnit = null

# =========================
# INIT
# =========================
func _ready() -> void:
	assert(map)
	assert(unit_manager)
	assert(turn_manager)
	assert(game_state)
	print("InputController pronto")

# =========================
# INPUT
# =========================
func _input(event: InputEvent) -> void:

	if not game_state.is_player_input_allowed():
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var mouse_pos: Vector2 = get_global_mouse_position()
		var grid: Vector2i = map.world_to_grid(mouse_pos)

		map.set_hovered_tile(grid)

		if not map.is_inside_map(grid):
			_reset_selection()
			return

		var unit: HeroUnit = unit_manager.get_unit_at(grid)

		# =========================
		# SELEÇÃO
		# =========================
		if is_instance_valid(unit) \
			and unit.faction == Faction.Type.ALLY \
			and not unit.has_acted:

			selected_unit = unit
			print("\n=== SELECIONOU ===")
			print("Unit:", unit)
			print("Pos:", unit.grid_pos)
		
			var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()
			var reachable: Array[Vector2i] = map.compute_reachable_tiles(unit, blocked)
		
			# 🟦 movimento
			map.show_reachable_tiles(reachable)
		
			# 🔴 ataque CORRETO
			var attack_tiles: Array[Vector2i] = map.compute_attack_tiles_from_movement(
				unit,
				reachable
			)
			
			map.show_attack_tiles(attack_tiles)
		
			var targets = map.get_attackable_units(unit, attack_tiles)
			print("Alvos possíveis:", targets)

			return

		# =========================
		# ATAQUE
		# =========================
		if is_instance_valid(selected_unit) and is_instance_valid(unit):
			if unit.faction == Faction.Type.ENEMY:
				
				var sim: Dictionary = CombatResolver.simulate_attack(
					selected_unit,
					unit
				)
				
				print("Dano causado:", sim["damage_to_defender"])
				print("Dano recebido:", sim["damage_to_attacker"])
				
				var dist = map.grid_distance(selected_unit.grid_pos, unit.grid_pos)
				
				if dist >= selected_unit.attack_range_min and dist <= selected_unit.attack_range_max:
					
					game_state.set_state(GameStateManager.State.PLAYER_ANIMATING)
					
					map.execute_attack(selected_unit, unit)
					
					selected_unit.has_acted = true
					selected_unit = null
					map.clear_selection()
					
					game_state.set_state(GameStateManager.State.IDLE)
					
					if unit_manager.all_player_units_acted():
						turn_manager.end_current_turn()
					
					return

		# =========================
		# MOVIMENTO
		# =========================
		if is_instance_valid(selected_unit) and map.is_tile_reachable(grid):
			game_state.set_state(GameStateManager.State.PLAYER_ANIMATING)

			var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()

			var path: Array[Vector2i] = map.get_grid_path(
				selected_unit.grid_pos,
				grid,
				selected_unit,
				blocked
			)

			if path.is_empty():
				return

			var tween: Tween = map.move_unit_along_path(selected_unit, path)

			if tween != null:
				await tween.finished

			map.clear_hover_preview()

			selected_unit.has_acted = true
			selected_unit = null
			map.clear_selection()

			game_state.set_state(GameStateManager.State.IDLE)

			if unit_manager.all_player_units_acted():
				turn_manager.end_current_turn()

			return

		# =========================
		# RESET
		# =========================
		_reset_selection()

# =========================
# UTIL
# =========================
func _reset_selection() -> void:
	selected_unit = null
	map.clear_selection()
	
	map.clear_selection()
	map.clear_hover_preview()
	
	preview_ui.hide_preview()

func _process(delta: float) -> void:
	if selected_unit == null:
		return
	
	if not is_instance_valid(selected_unit):
		return
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	var grid: Vector2i = map.world_to_grid(mouse_pos)
	
	map.set_hovered_tile(grid)
	
	#=======================
	#HOVER MOVIEMENTO
	#=======================
	if map.is_tile_reachable(grid):
		var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()
		
		var path: Array[Vector2i] = map.get_grid_path(
			selected_unit.grid_pos,
			grid,
			selected_unit,
			blocked
		)
		
		map.show_preview_path(path)
		
		#=======================
		#PREVIEW ATAQUE
		#=======================
		var fake_reachable: Array[Vector2i] = [grid]
		
		var hover_attack_tiles = map.compute_attack_tiles_from_movement(
			selected_unit,
			fake_reachable
		)
		
		map.show_hover_attack_tiles(hover_attack_tiles)
		
	else:
		map.clear_hover_preview()
		
	#============================
	#COMBAT PREVIEW
	#============================
	var unit: HeroUnit = unit_manager.get_unit_at(grid)
	
	if is_instance_valid(unit) and unit.faction == Faction.Type.ENEMY:
		
		if map.attack_tiles.has(grid):
			
			var sim = CombatResolver.simulate_attack(
				selected_unit,
				unit
			)
			
			preview_ui.show_preview(sim)
			
		else:
			preview_ui.hide_preview()
	else:
		preview_ui.hide_preview()


func can_attack(attacker: HeroUnit, target: HeroUnit) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false
	
	if attacker.faction == target.faction:
		return false
	
	var dist = map.grid_distance(attacker.grid_position, target.grid_position)
	
	return dist >= attacker.attack_range_min and dist <= attacker.attack_range_max
