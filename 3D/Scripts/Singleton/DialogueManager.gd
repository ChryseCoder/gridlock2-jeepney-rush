extends CanvasLayer
## A persistent overlay above level HUDs. No delayed callbacks survive cancellation.

const TEXT_BOX_SCENE := preload("res://3D/Scenes/Dialogue/dialogue.tscn")
const LINE_HOLD_TIME := 1.5
const DIALOGUE_GAP := 0.2

var dialog_lines: Array[String] = []
var dialogue_queue: Array[Dictionary] = []
var current_line_index := 0
var text_box: Control
var text_box_position := Vector2(24, 24)
var is_dialog_active := false
var can_advance_line := false
var _generation := 0
var _line_hold_left := -1.0
var _gap_left := -1.0

func _ready() -> void:
	layer = 100

func start_dialog(position: Vector2, lines: Array[String]) -> void:
	var nonempty_lines: Array[String] = []
	for line in lines:
		if not line.is_empty():
			nonempty_lines.append(line)
	if nonempty_lines.is_empty():
		return
	dialogue_queue.append({"position": position, "lines": nonempty_lines})
	if not is_dialog_active:
		_start_next_dialogue()

func _process(delta: float) -> void:
	if _line_hold_left >= 0.0:
		_line_hold_left -= delta
		if _line_hold_left <= 0.0:
			_line_hold_left = -1.0
			_advance_line()
	elif _gap_left >= 0.0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_gap_left = -1.0
			_start_next_dialogue()

func _show_text_box() -> void:
	_discard_text_box()
	text_box = TEXT_BOX_SCENE.instantiate()
	add_child(text_box)
	text_box.global_position = Vector2(24, 24)
	text_box.finished_displaying.connect(_on_text_box_finished_displaying.bind(_generation))
	can_advance_line = false
	text_box.display_text(dialog_lines[current_line_index])

func _on_text_box_finished_displaying(generation: int) -> void:
	if generation != _generation or not is_dialog_active:
		return
	can_advance_line = true
	_line_hold_left = LINE_HOLD_TIME

func _advance_line() -> void:
	_discard_text_box()
	can_advance_line = false
	current_line_index += 1
	if current_line_index < dialog_lines.size():
		_show_text_box()
	else:
		current_line_index = 0
		dialog_lines.clear()
		_gap_left = DIALOGUE_GAP

func _start_next_dialogue() -> void:
	if dialogue_queue.is_empty():
		is_dialog_active = false
		return
	var next_dialogue: Dictionary = dialogue_queue.pop_front()
	dialog_lines.assign(next_dialogue["lines"])
	text_box_position = next_dialogue["position"]
	current_line_index = 0
	is_dialog_active = true
	_show_text_box()

func _discard_text_box() -> void:
	if is_instance_valid(text_box):
		text_box.hide()
		text_box.queue_free()
	text_box = null

func cancel_dialogue() -> void:
	_generation += 1
	_line_hold_left = -1.0
	_gap_left = -1.0
	is_dialog_active = false
	can_advance_line = false
	current_line_index = 0
	dialog_lines.clear()
	dialogue_queue.clear()
	_discard_text_box()
