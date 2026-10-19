extends Control

signal timer_finished
signal penalty_applied(reason: StringName, seconds: float)

@export var speedneedle_min_angle: float = -120.0
@export var speedneedle_max_angle: float = 120.0

@export var fuelneedle_min_angle: float = -68.0
@export var fuelneedle_max_angle: float = 68.0

@export var start_time: float = 120.0  # countdown length in seconds

@onready var speed_needle: TextureRect = $Needle_Speedometer
@onready var fuel_needle: TextureRect = $Needle_Fuel
@onready var gear: RichTextLabel = $Gear
@onready var clock: RichTextLabel = $Clock

@export_group("Penalties")
@export_range(0.0, 30.0, 1.0) var penalty_seconds: float = 5.0
@export_range(0.0, 30.0, 0.5) var penalty_cooldown: float = 4.0

var _penalty_time_left: float = 0.0

var player: CharacterBody3D
var time_left: float = 0.0
var running: bool = false

func _ready() -> void:
	add_to_group("MissionTimer")
	TrafficManager.red_light_violation.connect(_on_red_light_violation)

	player = get_tree().get_first_node_in_group("Player")
	start_countdown(start_time)


func start_countdown(seconds: float) -> void:
	time_left = maxf(seconds, 0.0)
	_penalty_time_left = 0.0
	running = true
	_update_clock()

func _update_clock() -> void:
	var total: int = ceili(time_left)
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	clock.text = "%02d:%02d" % [minutes, seconds]

func _process(delta: float) -> void:
	if running:
		_penalty_time_left = maxf(
			_penalty_time_left - delta,
			0.0
		)
		time_left = max(time_left - delta, 0.0)
		_update_clock()
		_finish_countdown_if_needed()


	if player == null:
		player = get_tree().get_first_node_in_group("Player")
		return
#Speedometer
	var ratio: float = clamp(abs(player.speed) / player.max_speed, 0.0, 1.0)
	speed_needle.rotation_degrees = lerp(speedneedle_min_angle, speedneedle_max_angle, ratio)
#Fuel meter
	var fuel_ratio: float = clamp(player.fuel / player.max_fuel, 0.0, 1.0)
	fuel_needle.rotation_degrees = lerp(fuelneedle_min_angle, fuelneedle_max_angle, fuel_ratio)
#Gear Indicator
	if player.speed <= -0.1:
		gear.text = "R"
	else:
		gear.text = "%d" % player.current_gear

func apply_penalty(reason: StringName) -> bool:
	if not running or get_tree().paused or _penalty_time_left > 0.0:
		return false

	var mission_manager = get_tree().get_first_node_in_group(
		"MissionManager"
	)

	if mission_manager and (
		mission_manager.mission_completed
		or mission_manager.mission_failed
	):
		return false

	_penalty_time_left = penalty_cooldown
	time_left = maxf(time_left - penalty_seconds, 0.0)

	_update_clock()
	penalty_applied.emit(reason, penalty_seconds)
	_finish_countdown_if_needed()

	return true


func _on_red_light_violation(
	vehicle: Node,
	_intersection: Node,
	_approach: StringName
) -> void:
	if vehicle.is_in_group("Player") or vehicle.is_in_group("player"):
		apply_penalty(&"red_light")


func _finish_countdown_if_needed() -> void:
	if not running or time_left > 0.0:
		return

	running = false
	timer_finished.emit()

	var mission_manager = get_tree().get_first_node_in_group(
		"MissionManager"
	)

	if mission_manager:
		mission_manager.fail_mission()	
