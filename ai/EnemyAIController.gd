extends Node
class_name EnemyAIController

@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath

@onready var map: BattleMap = get_node(battle_map_path)
@onready var unit_manager: UnitManager = get_node(unit_manager_path)
@onready var turn_manager: TurnManager = get_node(turn_manager_path)

func _ready() -> void:
	turn_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	print("EnemyAIController pronto")

# =========================
# TURNO INIMIGO
# =========================
func _on_enemy_turn_started() -> void:
	print("IA inimiga processando...")
	unit_manager.reset_units_turn("enemy")

	await _process_enemy_turn()

	print("IA terminou")
	turn_manager.end_current_turn()

# =========================
# LOOP PRINCIPAL
# =========================
func _process_enemy_turn() -> void:
	var enemies: Array[HeroUnit] = unit_manager.get_units_by_faction("enemy")

	for enemy in enemies:
		if enemy.has_acted:
			continue

		await _enemy_take_action(enemy)

# =========================
# AÇÃO INDIVIDUAL (ESSA FUNÇÃO ESTAVA FALTANDO)
# =========================
func _enemy_take_action(enemy: HeroUnit) -> void:
	var target: HeroUnit = _get_closest_ally(enemy)

	if target == null:
		enemy.has_acted = true
		return

	# 1️⃣ Atacar se adjacente
	if map.is_adjacent(enemy.grid_pos, target.grid_pos):
		map.execute_attack(enemy, target)
		enemy.has_acted = true
		await _small_delay()
		return

	# 2️⃣ Mover em direção ao alvo
	var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()
	blocked.erase(target.grid_pos)

	var path: Array[Vector2i] = map.get_grid_path(
	enemy.grid_pos,
	target.grid_pos,
	enemy,
	blocked
)

	if path.size() <= 1:
		enemy.has_acted = true
		return

	var steps: int = min(enemy.move_range, path.size() - 1)
	var move_path: Array[Vector2i] = path.slice(0, steps + 1)

	var tween: Tween = map.move_unit_along_path(enemy, move_path)
	if tween != null:
		await tween.finished

	# 3️⃣ Ataque pós-movimento
	if map.is_adjacent(enemy.grid_pos, target.grid_pos):
		map.execute_attack(enemy, target)

	enemy.has_acted = true
	await _small_delay()

# =========================
# UTIL
# =========================
func _get_closest_ally(from: HeroUnit) -> HeroUnit:
	var allies: Array[HeroUnit] = unit_manager.get_units_by_faction("ally")

	var closest: HeroUnit = null
	var best_dist: int = 999999

	for ally in allies:
		var dist: int = abs(ally.grid_pos.x - from.grid_pos.x) \
			+ abs(ally.grid_pos.y - from.grid_pos.y)

		if dist < best_dist:
			best_dist = dist
			closest = ally

	return closest

func _small_delay() -> void:
	await get_tree().create_timer(0.15).timeout
