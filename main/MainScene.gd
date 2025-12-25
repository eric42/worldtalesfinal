extends Node2D

@onready var map = $BattleMap
@onready var hero_scene: PackedScene = preload("res://units/HeroUnit.tscn")

enum Turn {
	PLAYER,
	ENEMY
}

var current_turn: Turn = Turn.PLAYER

func _ready():
	print("MainScene pronta")
	_start_player_turn()
	
	map.spawn_unit(hero_scene, Vector2i(2, 2), "ally")
	map.spawn_unit(hero_scene, Vector2i(4, 2), "ally")
	map.spawn_unit(hero_scene, Vector2i(7, 6), "enemy")

func _start_player_turn():
	current_turn = Turn.PLAYER
	map.is_player_turn = true
	
	for u in map.units:
		u.has_acted = false
	
	print("Turno do PLAYER")

func end_player_turn():
	print("Fim do turno do PLAYER")
	_start_enemy_turn()

func _start_enemy_turn():
	current_turn = Turn.ENEMY
	map.is_player_turn = false
	print("Turno do ENEMY")
	
	await get_tree().create_timer(1.0).timeout
	_start_player_turn()
