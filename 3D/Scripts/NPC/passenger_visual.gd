extends Node3D

@onready var body: AnimatedSprite3D = $Body
@onready var outfit: AnimatedSprite3D = $Outfit
@onready var hair: AnimatedSprite3D = $Hair


var body_options: Array[SpriteFrames] = [
	preload("res://3D/Assets/Images/Sprites/Passengers/body_01.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/body_02.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/body_03.tres")
]

var outfit_options: Array[SpriteFrames] = [
	preload("res://3D/Assets/Images/Sprites/Passengers/outfit_01.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/outfit_02.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/outfit_03.tres")
]

var hair_options: Array[SpriteFrames] = [
	preload("res://3D/Assets/Images/Sprites/Passengers/hair_01.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/hair_02.tres"),
	preload("res://3D/Assets/Images/Sprites/Passengers/hair_03.tres")
]


func _ready():
	randomize_appearance()

	body.frame_changed.connect(_on_body_frame_changed)

	play_animation("idle_down")


func randomize_appearance():
	body.sprite_frames = body_options.pick_random()
	outfit.sprite_frames = outfit_options.pick_random()
	hair.sprite_frames = hair_options.pick_random()

func get_appearance() -> Dictionary:
	return {
		"body": body.sprite_frames,
		"outfit": outfit.sprite_frames,
		"hair": hair.sprite_frames
	}

func set_appearance(data: Dictionary):
	body.sprite_frames = data["body"]
	outfit.sprite_frames = data["outfit"]
	hair.sprite_frames = data["hair"]

func play_animation(animation_name: StringName):
	if body.animation != animation_name:
		body.play(animation_name)

	outfit.animation = animation_name
	hair.animation = animation_name

	outfit.frame = body.frame
	hair.frame = body.frame


func set_flip_h(value: bool):
	body.flip_h = value
	outfit.flip_h = value
	hair.flip_h = value


func _on_body_frame_changed():
	outfit.frame = body.frame
	hair.frame = body.frame
