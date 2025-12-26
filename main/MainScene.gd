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
	map.start_player_turn()
	print("Turno do PLAYER")

func end_player_turn():
	print("Fim do turno do PLAYER")
	_start_enemy_turn()

func end_enemy_turn():
	print("Fim do turno do ENEMY")
	_start_player_turn()

func _start_enemy_turn():
	current_turn = Turn.ENEMY
	print("turno do ENEMY")
	await map.start_enemy_turn()
	end_enemy_turn()
