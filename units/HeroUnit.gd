extends Node2D

var map: Node2D
var grid_pos: Vector2i
var faction: String
var move_range: int = 3

func _ready():
	print("HeroUnit pronta | grid =", grid_pos, "| faction =", faction)
