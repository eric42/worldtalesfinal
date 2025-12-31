extends Node2D

@onready var turn_manager: TurnManager = $TurnManager
@onready var unit_manager: UnitManager = $UnitManager
@onready var battle_map: BattleMap = $BattleMap

func _ready() -> void:
	print("MainScene pronta")

	unit_manager.spawn_unit(Vector2i(2, 2), "ally")
	unit_manager.spawn_unit(Vector2i(4, 2), "ally")
	unit_manager.spawn_unit(Vector2i(7, 6), "enemy")

	turn_manager.player_turn_started.connect(_on_player_turn_started)

func _on_player_turn_started() -> void:
	print("Turno do PLAYER")
	unit_manager.reset_units_turn("ally")
	battle_map.clear_selection()

func _on_enemy_turn_started() -> void:
	unit_manager.reset_units_turn("enemy")
