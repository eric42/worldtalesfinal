extends Node2D
class_name HeroUnit

var map: BattleMap
var grid_pos: Vector2i
var faction: String

#stats
var max_hp: int = 20
var hp : int = 20
var atk : int = 10
var def : int = 5
var res : int = 3
var spd : int = 5

var move_range: int = 3

var has_acted := false

func _ready():
	print("HeroUnit pronta | grid =", grid_pos, "| faction =", faction)

func reset_turn():
	has_acted = false

func is_alive() -> bool:
	return hp > 0
