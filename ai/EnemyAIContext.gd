extends RefCounted
class_name  EnemyAIContext

enum BattlePhase {
	EARLY,
	MID,
	LATE
}

var ally_count: int
var enemy_count: int

var ally_avg_hp: float
var enemy_avg_hp: float

var phase: BattlePhase

const FACTION_ALLY: String = "ally"
const FACTION_ENEMY: String = "enemy"

func update(unit_manager: UnitManager) -> void:
	var allies : Array[HeroUnit] = unit_manager.get_units_by_faction(Faction.Type.ALLY)
	var enemies : Array[HeroUnit] = unit_manager.get_units_by_faction(Faction.Type.ENEMY)
	
	ally_count = allies.size()
	enemy_count = enemies.size()
	
	ally_avg_hp = _avarage_hp(allies)
	enemy_avg_hp = _avarage_hp(enemies)
	
	phase = _calculate_phase()

func _avarage_hp(units: Array[HeroUnit]) -> float:
	if units.is_empty():
		return 0.0
	
	var total := 0
	for u in units:
		total += u.hp
	
	return float(total) / units.size()

func _calculate_phase() -> BattlePhase:
	var total_units := ally_count + enemy_count
	
	if total_units >= 6:
		return BattlePhase.EARLY
	elif total_units >= 3:
		return BattlePhase.MID
	else:
		return BattlePhase.LATE
		
