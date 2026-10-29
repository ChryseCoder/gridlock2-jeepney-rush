extends Control

@export_file("*.tscn") var main_menu_scene := "res://3D/Scenes/Menu/main_menu.tscn"
@onready var stats: GridContainer = $Center/Panel/Margin/Column/Stats
@onready var penalty: Label = $Center/Panel/Margin/Column/Penalty
@onready var next_button: Button = $Center/Panel/Margin/Column/Actions/Next
var _next_level: String

func _ready() -> void:
	hide()

func show_results(results: Dictionary, next_level: String) -> void:
	_next_level = next_level
	stats.get_node("StartingValue").text = GameSession.money(results.starting_cash)
	stats.get_node("EarningsValue").text = GameSession.money(results.earnings)
	stats.get_node("FuelValue").text = GameSession.money(results.fuel_spending)
	stats.get_node("FinesValue").text = GameSession.money(results.fines)
	stats.get_node("NetValue").text = GameSession.money(results.net_income)
	stats.get_node("CashValue").text = GameSession.money(results.cash)
	stats.get_node("PointsValue").text = "%d  (+%d this level)" % [results.violation_points, results.level_points]
	stats.get_node("StopsValue").text = "%d tickets  /  %d evasions" % [results.tickets, results.evasions]
	if results.fuel_penalty:
		penalty.text = "%s in unpaid fines. Next level starts with 75%% fuel.\nThe shortfall is cleared by this fuel penalty." % GameSession.money(results.unpaid_fines)
	else:
		penalty.text = "All fines settled. Violation points carry into the next level."
	next_button.text = "Next level" if not _next_level.is_empty() else "Drive again"
	show()
	next_button.grab_focus()

func _on_next_pressed() -> void:
	DialogueManager.cancel_dialogue()
	get_tree().paused = false
	if _next_level.is_empty():
		GameSession.reset_campaign()
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(_next_level)

func _on_menu_pressed() -> void:
	DialogueManager.cancel_dialogue()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)
