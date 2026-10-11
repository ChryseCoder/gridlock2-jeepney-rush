extends Node

@export var mission_complete_window: Control

@export var mission_failed_window: Control

var mission_completed: bool = false

var mission_failed: bool = false

func complete_mission():
	if mission_completed:
		return

	mission_completed = true

	print("Mission Complete!")

	if mission_complete_window:
		mission_complete_window.show()

	get_tree().paused = true

func fail_mission():
	if mission_completed or mission_failed:
		return

	mission_failed = true

	print("Mission Failed!")

	if mission_failed_window:
		mission_failed_window.show()

	get_tree().paused = true
