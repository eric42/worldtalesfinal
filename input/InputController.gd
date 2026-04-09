extends Node2D
class_name InputController

@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath
@export var game_state_path: NodePath

@onready var map: BattleMap = get_node(battle_map_path)
@onready var unit_manager: UnitManager = get_node(unit_manager_path)
@onready var turn_manager: TurnManager = get_node(turn_manager_path)
@onready var game_state: GameStateManager = get_node(game_state_path)

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
		if unit != null \
		and unit.faction == Faction.Type.ALLY \
		and not unit.has_acted:

			selected_unit = unit

			var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()
			var reachable: Array[Vector2i] = map.compute_reachable_tiles(unit, blocked)

			map.show_reachable_tiles(reachable)
			
			var attack_tiles: Array[Vector2i] = map.compute_attack_tiles_from_movement(
				reachable,
				blocked
				)
				
			map. show_attack_tiles(attack_tiles)
			
			return

		# =========================
		# ATAQUE
		# =========================
		if selected_unit != null and unit != null:
			
			if unit.faction == Faction.Type.ENEMY:
				
				
				var sim: Dictionary = CombatResolver.simulate_attack(
					selected_unit,
					unit
				)
				
				print("Preview:")
				print("Dano causado:", sim["damage_to_defender"])
				print("Dano recebido:", sim["damage_to_attacker"])
				
				if map.is_adjacent(selected_unit.grid_pos, unit.grid_pos):
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
		if selected_unit != null and map.is_tile_reachable(grid):

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
