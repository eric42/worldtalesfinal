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
	# ancora no canto inferior esquerdo
	await get_tree().process_frame
	
	anchor_left = 0
	anchor_top = 1
	anchor_right = 0
	anchor_bottom = 1
	
	# deslocamento da borda
	offset_left = 20
	offset_bottom = -60
	custom_minimum_size = Vector2(200, 100)

# =========================
# PREVIEW
# =========================
func show_preview(data: Dictionary) -> void:
	damage_to_defender.text = "Dano: " + str(data["damage_to_defender"])
	damage_to_attacker.text = "Contra-Ataque: " + str(data["damage_to_attacker"])
	
	visible = true

func hide_preview() -> void:
	visible = false
