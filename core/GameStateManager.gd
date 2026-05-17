extends Node
class_name GameStateManager

enum State {
	IDLE,
	PLAYER_ANIMATING,
	PLAYER_ACTION,
	ENEMY_TURN
}

var current_state: State = State.IDLE

signal state_changed(new_state: State)

func set_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_changed.emit(new_state)
	print("GameState →", State.keys()[new_state])

func is_player_input_allowed() -> bool:
	return current_state == State.IDLE

func is_enemy_turn() -> bool:
	return current_state == State.ENEMY_TURN
