extends Control

@export_file("*.tscn") var main_menu_scene: String

func _on_main_menu_button_pressed():
	DialogueManager.cancel_dialogue()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _on_retry_button_pressed():
	DialogueManager.cancel_dialogue()
	get_tree().paused = false
	get_tree().reload_current_scene()
