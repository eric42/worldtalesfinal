extends CanvasLayer
class_name ActionMenuUI

signal attack_selected
signal wait_selected
signal cancel_selected

@onready var attack_button: Button = $Panel/VBoxContainer/AttackButton
@onready var wait_button: Button = $Panel/VBoxContainer/WaitButton
@onready var cancel_button: Button = $Panel/VBoxContainer/CancelButton

func _ready() -> void:
	hide()

	attack_button.text = "Attack"
	wait_button.text = "Wait"
	cancel_button.text = "Cancel"

	attack_button.pressed.connect(_on_attack_pressed)
	wait_button.pressed.connect(_on_wait_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func show_menu(screen_pos: Vector2) -> void:
	offset = screen_pos
	show()

func _on_attack_pressed() -> void:
	hide()
	attack_selected.emit()

func _on_wait_pressed() -> void:
	hide()
	wait_selected.emit()

func _on_cancel_pressed() -> void:
	hide()
	cancel_selected.emit()

func set_attack_enabled(enabled: bool) -> void:
	attack_button.disabled = !enabled

func show_wait_only() -> void:
	attack_button.hide()
	wait_button.show()
	cancel_button.show()
	show()

func show_full_menu() -> void:
	attack_button.show()
	wait_button.show()
	cancel_button.show()
	show()
