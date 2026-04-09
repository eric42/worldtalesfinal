extends Node
class_name TurnManager

signal player_turn_started
signal enemy_turn_started

enum Turn { PLAYER, ENEMY }
var current_turn: Turn = Turn.PLAYER

@export var unit_manager_path: NodePath
@onready var unit_manager: UnitManager = get_node(unit_manager_path)

func start_player_turn() -> void:
	current_turn = Turn.PLAYER
	unit_manager.reset_units_turn(Faction.Type.ALLY)
	player_turn_started.emit()

func start_enemy_turn() -> void:
	current_turn = Turn.ENEMY
	unit_manager.reset_units_turn(Faction.Type.ENEMY)
	enemy_turn_started.emit()

func end_current_turn():
	if current_turn == Turn.PLAYER:
		start_enemy_turn()
	else:
		start_player_turn()
		
func is_player_turn() -> bool:
	return current_turn == Turn.PLAYER
