extends Node2D
const TILE_SIZE := 64
const WIDTH := 11
const HEIGHT := 11

@onready var units_container: Node2D = $Units
@onready var hero_scene: PackedScene = preload("res://units/HeroUnit.tscn")

var hovered_tile: Vector2i = Vector2i(-1, -1)

func _ready():
	print("BattleMap pronta (com Units)")
	queue_redraw()
	_spawn_test_square()

func _draw():
	for x in range(WIDTH):
		for y in range(HEIGHT):
			draw_rect(
				Rect2(
					Vector2(x, y) * TILE_SIZE,
					Vector2(TILE_SIZE, TILE_SIZE)
				),
				Color(1, 1, 1, 0.15),
				false
			)
	
	if hovered_tile.x >= 0 and hovered_tile.y >= 0:
		draw_rect(
			Rect2(
				Vector2(hovered_tile) * TILE_SIZE,
				Vector2(TILE_SIZE, TILE_SIZE)
			),
			Color(1, 1, 0, 0.25),
			true
		)

# apenas para teste visual
func _spawn_test_square():
	var u = hero_scene.instantiate()
	
	u.map = self
	u.grid_pos = Vector2i(2, 2)
	u.faction = "ally"
	
	u.position = Vector2(u.grid_pos) * TILE_SIZE
	
	units_container.add_child(u)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = get_local_mouse_position()
		var grid_x := int(mouse_pos.x / TILE_SIZE)
		var grid_y := int(mouse_pos.y / TILE_SIZE)
		
		hovered_tile = Vector2i(grid_x, grid_y)
		
		queue_redraw()
