extends Node
class_name TurnManager

signal player_turn_started
signal enemy_turn_started

enum Turn { PLAYER, ENEMY }
var current_turn: Turn = Turn.PLAYER

func start_player_turn() -> void:
	current_turn = Turn.PLAYER
	print("TurnManager → PLAYER")
	player_turn_started.emit()

func start_enemy_turn() -> void:
	current_turn = Turn.ENEMY
	print("TurnManager → ENEMY")
	enemy_turn_started.emit()

func end_current_turn() -> void:
	if current_turn == Turn.PLAYER:
		start_enemy_turn()
	else:
		start_player_turn()

func is_player_turn() -> bool:
	return current_turn == Turn.PLAYER
