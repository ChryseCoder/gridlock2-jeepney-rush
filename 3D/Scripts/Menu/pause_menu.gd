extends Control

@export_file("*.tscn") var main_menu_scene: String


func _ready():
	hide()


func pause_game():
	show()
	get_tree().paused = true


func resume_game():
	get_tree().paused = false
	hide()


func _on_resume_button_pressed():
	resume_game()


func _on_main_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _unhandled_input(event):
	if event.is_action_pressed("pause_game"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
