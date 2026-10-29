extends Node

@export var mission_failed_window: Control
@export var results_window: Control
@export_group("Economy")
## Optional next level. Leave empty for the single-level prototype.
@export_file("*.tscn") var next_level_scene: String

var mission_failed: bool = false
var mission_completed: bool = false
var remaining_mission_passengers: int = 0
var _initialized := false

func _ready() -> void:
	GameSession.begin_level()
	call_deferred("_initialize_level")

func _initialize_level() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		player.fuel = player.max_fuel * GameSession.starting_fuel_multiplier()
	remaining_mission_passengers = get_tree().get_nodes_in_group("MissionPassengers").size()
	_initialized = remaining_mission_passengers > 0

func passenger_arrived() -> void:
	if mission_failed or mission_completed or not _initialized:
		return
	remaining_mission_passengers = maxi(0, remaining_mission_passengers - 1)

func _process(_delta: float) -> void:
	if get_tree().paused or not _initialized or mission_failed or mission_completed:
		return
	# Let the final passenger finish walking and any ticket/pursuit resolve.
	if remaining_mission_passengers == 0 and not GameSession.has_active_encounters() and not DialogueManager.is_dialog_active:
		complete_mission()

func complete_mission() -> void:
	if mission_failed or mission_completed or GameSession.has_active_encounters():
		return
	mission_completed = true
	DialogueManager.cancel_dialogue()
	var results := GameSession.finish_level()
	if results_window:
		results_window.show_results(results, next_level_scene)
	get_tree().paused = true

func fail_mission() -> void:
	if mission_failed or mission_completed:
		return
	mission_failed = true
	DialogueManager.cancel_dialogue()
	if mission_failed_window:
		mission_failed_window.show()
	get_tree().paused = true
