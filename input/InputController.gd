extends Node
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

func _ready() -> void:
	assert(map)
	assert(unit_manager)
	assert(turn_manager)
	assert(game_state)
	print("InputController pronto")

func _input(event: InputEvent) -> void:
	if not game_state.is_player_input_allowed():
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var grid := map.mouse_to_grid(event.position)
		var unit := unit_manager.get_unit_at(grid)

		# =========================
		# SELEÇÃO
		# =========================
		if unit and unit.faction == "ally" and not unit.has_acted:
			selected_unit = unit

			var blocked := unit_manager.get_occupied_tiles()
			var reachable := map.compute_reachable_tiles(unit, blocked)

			map.show_reachable_tiles(reachable)
			return

		# =========================
		# MOVIMENTO
		# =========================
		if selected_unit and map.is_tile_reachable(grid):
			game_state.set_state(GameStateManager.State.PLAYER_ANIMATING)

			var blocked := unit_manager.get_occupied_tiles()
			var path := map.get_grid_path(
				selected_unit.grid_pos,
				grid,
				selected_unit,
				blocked
			)

			var tween := map.move_unit_along_path(selected_unit, path)
			await tween.finished

			selected_unit.has_acted = true
			selected_unit = null
			map.clear_selection()

			game_state.set_state(GameStateManager.State.IDLE)

			if unit_manager.all_player_units_acted():
				turn_manager.end_current_turn()

func _reset_selection() -> void:
	selected_unit = null
	map.clear_selection()
