extends Node

@export var mission_failed_window: Control

var mission_failed: bool = false


func fail_mission():
	if mission_failed:
		return

	mission_failed = true

	print("Mission Failed!")

	if mission_failed_window:
		mission_failed_window.show()

	get_tree().paused = true
