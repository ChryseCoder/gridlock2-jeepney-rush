extends Node


@onready var text_box_scene = preload("res://3D/Scenes/Dialogue/dialogue.tscn")


var dialog_lines: Array[String] = []
var current_line_index = 0

var text_box
var text_box_position: Vector2

var is_dialog_active = false
var can_advance_line = false


func start_dialog(position: Vector2, lines: Array[String]):
	if is_dialog_active:
		return

	dialog_lines = lines
	text_box_position = position
	current_line_index = 0
	is_dialog_active = true

	_show_text_box()
	
func _show_text_box():
	text_box = text_box_scene.instantiate()
	text_box.finished_displaying.connect(_on_text_box_finished_displaying)
	get_tree().root.add_child(text_box)
	text_box.global_position = Vector2(24, 24)
	text_box.display_text(dialog_lines[current_line_index])
	can_advance_line = false
	
func _on_text_box_finished_displaying():
	print("Dialogue line finished!")
	can_advance_line = true

	await get_tree().create_timer(1.5).timeout

	if not is_dialog_active:
		return

	if is_instance_valid(text_box):
		text_box.queue_free()

	current_line_index += 1

	if current_line_index >= dialog_lines.size():
		is_dialog_active = false
		current_line_index = 0
		return

	_show_text_box()
