extends Node
class_name EnemyAIController

# =========================
# DEPENDÊNCIAS
# =========================
@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath
@export var game_state_path: NodePath

@onready var map: BattleMap = get_node(battle_map_path)
@onready var unit_manager: UnitManager = get_node(unit_manager_path)
@onready var turn_manager: TurnManager = get_node(turn_manager_path)
@onready var game_state: GameStateManager = get_node(game_state_path)

var context := EnemyAIContext.new()

# =========================
# GODOT
# =========================
func _ready() -> void:
	assert(game_state)
	turn_manager.enemy_turn_started.connect(_on_enemy_turn_started)
	print("EnemyAIController pronto")

# =========================
# TURNO INIMIGO
# =========================
func _on_enemy_turn_started() -> void:
	context.update(unit_manager)
	
	print("IA inimiga processando...")
	print("Contexto:",
		" aliados =", context.ally_count,
		" inimigos =", context.enemy_count,
		" fase =", EnemyAIContext.BattlePhase.keys()[context.phase]
	)
	
	await _process_enemy_turn()
	turn_manager.end_current_turn()


# =========================
# LOOP PRINCIPAL
# =========================
func _process_enemy_turn() -> void:
	var enemies: Array[HeroUnit] = unit_manager.get_units_by_faction("enemy")
	print("Inimigos encontrados:", enemies.size())
	
	for enemy: HeroUnit in enemies:
		if enemy.has_acted:
			continue
		
		print("IA avaliando inimigo:", enemy.grid_pos)
		await _enemy_take_action(enemy)

# =========================
# AÇÃO INDIVIDUAL
# =========================
func _enemy_take_action(enemy: HeroUnit) -> void:
	var target: HeroUnit = _choose_best_target(enemy)

	# Sem alvo
	if target == null:
		enemy.has_acted = true
		return

	# 1️⃣ Ataque direto
	if map.is_adjacent(enemy.grid_pos, target.grid_pos):
		map.execute_attack(enemy, target)
		enemy.has_acted = true
		await _delay()
		return

	# 2️⃣ Movimento em direção ao alvo
	var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()

	var best_path: Array[Vector2i] = []

	for dir in [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]:
		var adjacent: Vector2i = target.grid_pos + dir

		if not map.is_inside_map(adjacent):
			continue
		if adjacent in blocked:
			continue

		var path := map.get_grid_path(
			enemy.grid_pos,
			adjacent,
			enemy,
			blocked
		)

		if path.is_empty():
			continue

		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path

		if path.size() <= 1:
			enemy.has_acted = true
			return

	var steps: int = min(enemy.move_range, best_path.size() - 1)
	var move_path := best_path.slice(0, steps + 1)

	var tween := map.move_unit_along_path(enemy, move_path)
	if tween:
		await tween.finished

	# 3️⃣ Ataque pós-movimento
	if map.is_adjacent(enemy.grid_pos, target.grid_pos):
		map.execute_attack(enemy, target)

	enemy.has_acted = true
	await _delay()

# =========================
# UTIL
# =========================
func _choose_best_target(enemy: HeroUnit) -> HeroUnit:
	var best_target: HeroUnit = null
	var best_score : float = -INF
	var aggression : float = _get_aggression_multiplier()
	
	var allies: Array[HeroUnit] = unit_manager.get_units_by_faction("ally")
	
	for ally in allies:
		if not ally.is_alive():
			continue
		
		var score : float = 0.0
		
		#priorizar alvos feridos
		score += float(ally.max_hp - ally.hp) * 2.0 * aggression
		
		#prioriza ameaças
		score += float(ally.atk) * aggression
		
		#penalizar distância
		var dist: int = abs(ally.grid_pos.x - enemy.grid_pos.x) + abs(ally.grid_pos.y - enemy.grid_pos.y)
		score -= float(dist) * 5.0
		
		if score > best_score:
			best_score = score
			best_target = ally
	
	return best_target

func _delay() -> void:
	await get_tree().create_timer(0.15).timeout

func _get_aggression_multiplier() -> float:
	match context.phase:
		EnemyAIContext.BattlePhase.EARLY:
			return 1.3
		EnemyAIContext.BattlePhase.MID:
			return 1.0
		EnemyAIContext.BattlePhase.LATE:
			return 0.7
	return 1.0
