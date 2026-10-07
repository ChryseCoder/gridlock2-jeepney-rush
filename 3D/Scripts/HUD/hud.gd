extends Control

signal timer_finished

@export var speedneedle_min_angle: float = -120.0
@export var speedneedle_max_angle: float = 120.0

@export var fuelneedle_min_angle: float = -68.0
@export var fuelneedle_max_angle: float = 68.0

@export var start_time: float = 120.0  # countdown length in seconds

@onready var speed_needle: TextureRect = $Needle_Speedometer
@onready var fuel_needle: TextureRect = $Needle_Fuel
@onready var gear: RichTextLabel = $Gear
@onready var clock: RichTextLabel = $Clock

var player: CharacterBody3D
var time_left: float = 0.0
var running: bool = false

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	start_countdown(start_time)

func start_countdown(seconds: float) -> void:
	time_left = seconds
	running = true
	_update_clock()

func _update_clock() -> void:
	var total: int = ceili(time_left)
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	clock.text = "%02d:%02d" % [minutes, seconds]

func _process(delta: float) -> void:
# Countdown runs before the player check so it never freezes
	if running:
		time_left = max(time_left - delta, 0.0)
		_update_clock()
		if time_left <= 0.0:
			running = false
			timer_finished.emit()

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
