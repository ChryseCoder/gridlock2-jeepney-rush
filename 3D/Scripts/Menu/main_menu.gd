extends Control

@export_file("*.tscn") var game_scene: String

@onready var settings_panel = $SettingsPanel


func _ready():
	settings_panel.hide()


func _on_play_button_pressed():
	get_tree().change_scene_to_file(game_scene)


func _on_settings_button_pressed():
	settings_panel.show()


func _on_close_setting_pressed():
	settings_panel.hide()


func _on_exit_button_pressed():
	get_tree().quit()


func _on_master_volume_value_changed(value):
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value)
	)


func _on_music_volume_value_changed(value):
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(value)
	)


func _on_sfx_volume_value_changed(value):
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(value)
	)
