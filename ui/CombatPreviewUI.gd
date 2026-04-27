extends Control
class_name CombatPreviewUI

# =========================
# REFERÊNCIAS
# =========================
@onready var damage_to_defender: Label = $Panel/VBoxContainer/DamageToDefender
@onready var damage_to_attacker: Label = $Panel/VBoxContainer/DamageToAttacker

# =========================
# LAYOUT
# =========================
func _ready() -> void:
	await get_tree().process_frame
	
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	set_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	
	offset_left = 20
	offset_bottom = -20
	offset_top = -120 

# =========================
# PREVIEW
# =========================
func show_preview(data: Dictionary) -> void:
	damage_to_defender.text = "Dano: " + str(data["damage_to_defender"])
	damage_to_attacker.text = "Contra-Ataque: " + str(data["damage_to_attacker"])
	
	visible = true

func hide_preview() -> void:
	visible = false

func update_preview(attacker: HeroUnit, target: HeroUnit):
	var dist = abs(attacker.grid_pos.x - target.grid_pos.x) \
	+ abs(attacker.grid_pos.y - target.grid_pos.y)
	
	if dist < attacker.attack_range_min or dist > attacker.attack_range_max:
		hide_preview()
		return
