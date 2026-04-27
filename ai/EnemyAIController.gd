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
	var enemies: Array[HeroUnit] = unit_manager.get_units_by_faction(Faction.Type.ENEMY)
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
	var dist = map.grid_distance(enemy.grid_pos, target.grid_pos)

	# Sem alvo
	if target == null:
		enemy.has_acted = true
		return

	# 1️⃣ Ataque direto
	if dist >= enemy.attack_range_min and dist <= enemy.attack_range_max:
		if _should_attack(enemy, target):
			map.execute_attack(enemy, target)
		enemy.has_acted = true
		await _delay()
		return

	# 2️⃣ Movimento em direção ao alvo
	var blocked: Array[Vector2i] = unit_manager.get_occupied_tiles()
	
	var best_path: Array[Vector2i] = _choose_best_attack_position(
		enemy,
		target,
		blocked
	)
	
	if best_path.is_empty():
		enemy.has_acted = true
		return
	
	var tween: Tween = map.move_unit_along_path(enemy, best_path)
	
	if tween != null:
		await  tween.finished
	
	var steps: int = min(enemy.move_range, best_path.size() - 1)
	var move_path := best_path.slice(0, steps + 1)

	# 3️⃣ Ataque pós-movimento
	if dist >= enemy.attack_range_min and dist <= enemy.attack_range_max:
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
	
	var allies: Array[HeroUnit] = unit_manager.get_units_by_faction(Faction.Type.ALLY)
	
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

func _simulate_attack(attacker: HeroUnit, defender: HeroUnit) -> Dictionary:
	var damage_to_defender: int = CombatResolver.calculate_damage(
		attacker,
		defender,
		CombatResolver.AttackType.PHYSICAL,
		CombatResolver.Modifier.NEUTRAL,
		CombatResolver.Modifier.NEUTRAL
	)
	
	var defender_remaining_hp: int = defender.hp - damage_to_defender
	
	var damage_to_attacker: int = 0
	
	#contra-ataque simples(adjacente)
	if defender_remaining_hp > 0:
		damage_to_attacker = CombatResolver.calculate_damage(
			defender,
			attacker,
			CombatResolver.AttackType.PHYSICAL,
			CombatResolver.Modifier.NEUTRAL,
			CombatResolver.Modifier.NEUTRAL
		)
		
	return {
		"damage_to_defender": damage_to_defender,
		"damage_to_attacker": damage_to_attacker,
		"defender_remaining_hp": defender_remaining_hp
	}

func _should_attack(
	enemy: HeroUnit,
	target: HeroUnit
) -> bool:
	
	var result: Dictionary = _simulate_attack(enemy, target)
	
	var dmg_to_target: int = result["damage_to_defender"]
	var dmg_to_self: int = result["damage_to_attacker"]
	var target_hp_after: int = result["defender_remaining_hp"]
	
	#mata o alvo > sempre ataca
	if target_hp_after <= 0:
		return true
	
	#evita suicidio
	if enemy.hp - dmg_to_self <= 0:
		return false
	
	#ajuste por agressividade
	var aggression: float = _get_aggression_multiplier()
	
	#quanto mais agressivo, mais dano aceita trocar
	return float(dmg_to_target) * aggression >= float(dmg_to_self)

func _evaluate_position_risk(
	position: Vector2i,
	enemy: HeroUnit
) -> float:
	var risk: float = 0.0
	
	var allies: Array[HeroUnit] = unit_manager.get_units_by_faction(Faction.Type.ALLY)
	
	for ally: HeroUnit in allies:
		if not ally.is_alive():
			continue
		
		var dist: int = abs(ally.grid_pos.x - position.x) \
		+ abs(ally.grid_pos.y - position.y)
		
		#se aliados pode atacar essa posição
		if dist == 1:
			var potential_damage: int = CombatResolver.calculate_damage(
				ally,
				enemy,
				CombatResolver.AttackType.PHYSICAL,
				CombatResolver.Modifier.NEUTRAL,
				CombatResolver.Modifier.NEUTRAL
			)
			
			risk += float(potential_damage)
		
	return risk

func _choose_best_attack_position(
	enemy: HeroUnit,
	target: HeroUnit,
	blocked: Array[Vector2i]
) -> Array[Vector2i]:

	var best_path: Array[Vector2i] = []
	var best_score: float = -INF

	var directions: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]

	for dir: Vector2i in directions:
		var adjacent: Vector2i = target.grid_pos + dir

		if not map.is_inside_map(adjacent):
			continue
		if adjacent in blocked:
			continue

		var path: Array[Vector2i] = map.get_grid_path(
			enemy.grid_pos,
			adjacent,
			enemy,
			blocked
		)

		if path.is_empty():
			continue

		var steps: int = min(enemy.move_range, path.size() - 1)
		var move_path: Array[Vector2i] = path.slice(0, steps + 1)

		var final_position: Vector2i = move_path[move_path.size() - 1]

		# Simular ataque
		var sim: Dictionary = _simulate_attack(enemy, target)

		var damage_to_target: int = sim["damage_to_defender"]
		var damage_to_self: int = sim["damage_to_attacker"]
		var dist_to_target: int = abs(final_position.x - target.grid_pos.x) \
			+ abs(final_position.y - target.grid_pos.y)
		var risk: float = _evaluate_position_risk(final_position, enemy)

		# Score final
		var score: float = 0.0
		score += float(damage_to_target) * 2.0
		score -= float(damage_to_self)
		score -= risk

		# 🔥 NOVO: priorizar proximidade
		score -= float(dist_to_target) * 10.0

		if score > best_score:
			best_score = score
			best_path = move_path

	return best_path
