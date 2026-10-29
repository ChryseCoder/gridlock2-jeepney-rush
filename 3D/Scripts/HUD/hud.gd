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
@onready var delta_label: Label = $Delta

@export_group("Penalties")
@export_range(0.0, 30.0, 1.0) var penalty_seconds: float = 5.0
@export_range(0.0, 30.0, 0.5) var penalty_cooldown: float = 4.0

@export_group("Time Change Display")
@export_range(0.0, 5.0, 0.1) var delta_hold_time: float = 1.3
@export_range(0.1, 2.0, 0.1) var delta_fade_time: float = 0.5

var _penalty_time_left: float = 0.0

var _delta_tween: Tween

var player: CharacterBody3D
var time_left: float = 0.0
var running: bool = false



func _ready() -> void:
	add_to_group("MissionTimer")
	TrafficManager.red_light_violation.connect(_on_red_light_violation)

	player = get_tree().get_first_node_in_group("Player")
	start_countdown(start_time)


func start_countdown(seconds: float) -> void:
	_clear_time_delta()

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
	if not _can_change_time() or _penalty_time_left > 0.0:
		return false

	_penalty_time_left = penalty_cooldown
	_change_time(-penalty_seconds)
	penalty_applied.emit(reason, penalty_seconds)

	return true

func add_time(seconds: float) -> float:
	if not is_finite(seconds) or seconds <= 0.0 or not _can_change_time():
		return 0.0

	return _change_time(seconds)


func _can_change_time() -> bool:
	if not running or get_tree().paused:
		return false

	var mission_manager = get_tree().get_first_node_in_group(
		"MissionManager"
	)

	return not mission_manager or not mission_manager.mission_failed


func _change_time(seconds: float) -> float:
	var previous_time := time_left
	time_left = maxf(time_left + seconds, 0.0)

	var actual_change := time_left - previous_time

	_update_clock()

	if not is_zero_approx(actual_change):
		_show_time_delta(actual_change)

	_finish_countdown_if_needed()
	return actual_change


func _clear_time_delta() -> void:
	if _delta_tween and _delta_tween.is_valid():
		_delta_tween.kill()

	_delta_tween = null
	delta_label.text = ""
	delta_label.hide()
	delta_label.modulate.a = 1.0


func _show_time_delta(seconds: float) -> void:
	_clear_time_delta()

	var magnitude := String.num(absf(seconds), 3)

	if is_equal_approx(absf(seconds), roundf(absf(seconds))):
		magnitude = str(int(roundf(absf(seconds))))

	var prefix := "+" if seconds > 0.0 else "-"
	delta_label.text = "%s%ss" % [prefix, magnitude]

	delta_label.add_theme_color_override(
		"font_color",
		Color(0.35, 1.0, 0.55)
		if seconds > 0.0
		else Color(1.0, 0.3, 0.3)
	)

	delta_label.show()

	_delta_tween = create_tween()
	_delta_tween.tween_interval(delta_hold_time)
	_delta_tween.tween_property(
		delta_label,
		"modulate:a",
		0.0,
		delta_fade_time
	)
	_delta_tween.tween_callback(delta_label.hide)

func award_passenger_dropoff() -> float:
	return add_time(30.0)

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
