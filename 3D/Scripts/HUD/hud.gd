extends Control

@export var speedneedle_min_angle: float = -120.0
@export var speedneedle_max_angle: float = 120.0

@export var fuelneedle_min_angle: float = -68.0
@export var fuelneedle_max_angle: float = 68.0

@onready var speed_needle: TextureRect = $Needle_Speedometer
@onready var fuel_needle: TextureRect = $Needle_Fuel
@onready var gear: RichTextLabel = $Gear

var player: CharacterBody3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var ratio: float = clamp(abs(player.speed) / player.max_speed, 0.0, 1.0)
	speed_needle.rotation_degrees = lerp(speedneedle_min_angle, speedneedle_max_angle, ratio)

	var fuel_ratio: float = clamp(player.fuel / player.max_fuel, 0.0, 1.0)
	fuel_needle.rotation_degrees = lerp(fuelneedle_min_angle, fuelneedle_max_angle, fuel_ratio)

	if player.speed <= -0.1:
		gear.text = "R"
	else:
		gear.text = "%d" % player.current_gear
