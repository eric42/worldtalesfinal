extends Node2D
const TILE_SIZE := 64
const WIDTH := 11
const HEIGHT := 11

@onready var units_container: Node2D = $Units
@onready var hero_scene: PackedScene = preload("res://units/HeroUnit.tscn")

var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_unit: Node2D = null

var units: Array = []
var reachable_tiles: Array[Vector2i] = []

func _ready():
	print("BattleMap pronta (com Units)")
	queue_redraw()
	_spawn_test_unit()

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
	
	if selected_unit:
		for tile in reachable_tiles:
			draw_rect(
				Rect2(
					Vector2(tile) * TILE_SIZE,
					Vector2(TILE_SIZE, TILE_SIZE)
				),
				Color(0.3, 0.6, 1, 0.25),
				true
			)
	
	if selected_unit:
		draw_rect(
			Rect2(
				Vector2(selected_unit.grid_pos) * TILE_SIZE,
				Vector2(TILE_SIZE, TILE_SIZE)
			),
			Color(0, 1, 0, .35),
			true
		)

# apenas para teste visual
func _spawn_test_unit():
	var u1 = hero_scene.instantiate()
	u1.map = self
	u1.grid_pos = Vector2i(2, 2)
	u1.faction = "ally"
	u1.position = Vector2(u1.grid_pos) * TILE_SIZE
	units_container.add_child(u1)
	units.append(u1)
	
	var u2 = hero_scene.instantiate()
	u2.map = self
	u2.grid_pos = Vector2i(4, 2)
	u2.faction = "ally"
	u2.position = Vector2(u2.grid_pos) * TILE_SIZE
	units_container.add_child(u2)
	units.append(u2)
	
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = get_local_mouse_position()
		var grid = Vector2i(
			int(mouse_pos.x / TILE_SIZE),
			(mouse_pos.y / TILE_SIZE)
		)
		
		hovered_tile = grid
		
		var clicked_unit = _get_unit_at(grid)
		
		if clicked_unit:
			selected_unit = clicked_unit
			_compute_reachable_tiles(selected_unit)
			print("Unidade selecionada:", selected_unit)
		elif selected_unit and grid in reachable_tiles:
			_move_unit_to(selected_unit, grid)
			reachable_tiles.clear()
			print("Unidade movida para:", grid)
		else:
			selected_unit = null
			reachable_tiles.clear()
			print("Seleção limpa")
		
		queue_redraw()

func _get_unit_at(grid_pos: Vector2i):
	for u in units:
		if u.grid_pos == grid_pos:
			return u
	return null

func _move_unit_to(unit: Node2D, grid_pos: Vector2i):
	unit.grid_pos = grid_pos
	
	var target_pos = Vector2(grid_pos) * TILE_SIZE
	
	var tween := create_tween()
	tween.tween_property(
		unit,
		"position",
		target_pos,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _compute_reachable_tiles(unit):
	reachable_tiles.clear()
	
	for x in range(WIDTH):
		for y in range(HEIGHT):
			var tile := Vector2i(x, y)
			
			if tile == unit.grid_pos:
				continue
			
			if _is_tile_occupied(tile):
				continue
			
			var dist: int = abs(tile.x - unit.grid_pos.x) + abs(tile.y - unit.grid_pos.y)
		
			if dist <= unit.move_range:
				reachable_tiles.append(tile)

func _is_tile_occupied(grid_pos: Vector2i) -> bool:
	for u in units:
		if u.grid_pos == grid_pos:
			return true
	return false
