extends Node
class_name InputController

# =========================
# DEPENDÊNCIAS
# =========================
@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath

@onready var map: BattleMap = get_node_or_null(battle_map_path)
@onready var unit_manager: UnitManager = get_node_or_null(unit_manager_path)
@onready var turn_manager: TurnManager = get_node_or_null(turn_manager_path)

var input_enabled: bool = true

# =========================
# ESTADO
# =========================
var selected_unit: HeroUnit = null
var input_locked: bool = false

# =========================
# GODOT
# =========================
func _ready() -> void:
	if map == null or unit_manager == null or turn_manager == null:
		push_error("InputController: dependências não configuradas")
		set_process_unhandled_input(false)
		return

	print("InputController pronto")

# =========================
# INPUT
# =========================
func _input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if not turn_manager.is_player_turn():
		return

	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:

		var grid: Vector2i = map.mouse_to_grid(event.position)
		var unit: HeroUnit = unit_manager.get_unit_at(grid)

		# =========================
		# SELEÇÃO
		# =========================
		if unit and unit.faction == "ally" and not unit.has_acted:
			selected_unit = unit

			var blocked := unit_manager.get_occupied_tiles()
			var reachable := map.compute_reachable_tiles(selected_unit, blocked)

			map.show_reachable_tiles(reachable)
			return

		# =========================
		# MOVIMENTO
		# =========================
		if selected_unit and map.is_tile_reachable(grid):
			input_enabled = false

			var blocked := unit_manager.get_occupied_tiles()
			var path := map.get_grid_path(
				selected_unit.grid_pos,
				grid,
				selected_unit,
				blocked
			)

			if path.is_empty():
				input_enabled = true
				return

			var tween := map.move_unit_along_path(selected_unit, path)
			if tween != null:
				await tween.finished

			selected_unit.has_acted = true
			_reset_selection()

			input_enabled = true

			if unit_manager.all_player_units_acted():
				turn_manager.end_current_turn()


func _reset_selection() -> void:
	selected_unit = null
	map.clear_selection()
