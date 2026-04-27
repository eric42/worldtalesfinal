extends Node
class_name CombatResolver

enum AttackType {
	PHYSICAL,
	MAGIC
}

enum Modifier {
	VANTAGE,
	NEUTRAL,
	DISVANTAGE
}

static func modifier_value(mod: Modifier) -> float:
	match mod:
		Modifier.VANTAGE:
			return 1.2
		Modifier.NEUTRAL:
			return 1.0
		Modifier.DISVANTAGE:
			return 0.8
	return 1.0

static func weapon_triangle_value(mod: Modifier) -> float:
	match mod:
		Modifier.VANTAGE:
			return 1.5
		Modifier.NEUTRAL:
			return 1.0
		Modifier.DISVANTAGE:
			return 0.5 #staff
	return 1.0

static func calculate_damage(
	attacker,
	defender,
	attack_type: AttackType,
	skill_mod: Modifier,
	wt_mod: Modifier
) -> int:
	
	if attacker == null or defender == null:
		push_error("Attacker ou Defender é null")
		return 0
		
	var skill := modifier_value(skill_mod)
	var wt := weapon_triangle_value(wt_mod)
	
	var raw_damage: float = attacker.atk * skill * wt
	var defense := 0
	
	if attack_type == AttackType.PHYSICAL:
		defense = defender.def
	else:
		defense = defender.res
	
	var final_damage := int(raw_damage - defense)
	
	return max(1, final_damage)
	

static func simulate_attack(
	attacker: HeroUnit,
	defender: HeroUnit
) -> Dictionary:
	
	var damage_to_defender: int = calculate_damage(
		attacker,
		defender,
		AttackType.PHYSICAL,
		Modifier.NEUTRAL,
		Modifier.NEUTRAL
	)
	
	var defender_remaining_hp: int = defender.hp - damage_to_defender
	var dist = abs(attacker.grid_pos.x - defender.grid_pos.x) \
	+ abs(attacker.grid_pos.y - defender.grid_pos.y)
	
	var damage_to_attacker: int = 0
	
	# Contra-ataque (se sobreviver e estiver adjacente)
	if defender_remaining_hp > 0 \
		and dist >= defender.attack_range_min \
		and dist <= defender.attack_range_max:
		
		damage_to_attacker = calculate_damage(
			defender,
			attacker,
			AttackType.PHYSICAL,
			Modifier.NEUTRAL,
			Modifier.NEUTRAL
		)
	
	return {
		"damage_to_defender": damage_to_defender,
		"damage_to_attacker": damage_to_attacker,
		"defender_remaining_hp": defender_remaining_hp
	}
