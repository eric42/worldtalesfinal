extends Node2D

@onready var turn_manager: TurnManager = $TurnManager
@onready var unit_manager: UnitManager = $UnitManager
@onready var battle_map: BattleMap = $BattleMap
@onready var game_state: GameStateManager = $GameStateManager

func _ready() -> void:
	print("MainScene pronta")

	unit_manager.spawn_unit(Vector2i(2, 2), "ally")
	unit_manager.spawn_unit(Vector2i(4, 2), "ally")
	unit_manager.spawn_unit(Vector2i(7, 6), "enemy")

	turn_manager.player_turn_started.connect(_on_player_turn_started)
	turn_manager.enemy_turn_started.connect(_on_enemy_turn_started)

	turn_manager.start_player_turn()

func _on_player_turn_started() -> void:
	game_state.set_state(GameStateManager.State.IDLE)
	battle_map.clear_selection()
	print("Turno do PLAYER")

func _on_enemy_turn_started() -> void:
	game_state.set_state(GameStateManager.State.ENEMY_TURN)
	print("Turno do ENEMY")
