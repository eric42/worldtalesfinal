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
	
