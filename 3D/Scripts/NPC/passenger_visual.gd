extends Node3D

const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle_down", &"idle_left", &"idle_right", &"idle_up",
	&"walk_down", &"walk_left", &"walk_right", &"walk_up"
]


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


func randomize_appearance() -> void:
	set_appearance({
		"body": body_options.pick_random(),
		"outfit": outfit_options.pick_random(),
		"hair": hair_options.pick_random(),
		"outfit_tint": outfit.modulate
	})


func configure_appearance(
	randomized: bool, body_frames: SpriteFrames, outfit_frames: SpriteFrames,
	hair_frames: SpriteFrames, tint: Color
) -> void:
	if randomized:
		randomize_appearance()
	else:
		set_appearance({"body": body_frames, "outfit": outfit_frames, "hair": hair_frames})
	outfit.modulate = tint
	play_animation(&"idle_down")

func get_appearance() -> Dictionary:
	return {
		"body": body.sprite_frames,
		"outfit": outfit.sprite_frames,
		"hair": hair.sprite_frames,
		"outfit_tint": outfit.modulate
	}

func set_appearance(data: Dictionary) -> void:
	# Assign resources without editing them, so shared .tres files remain unchanged.
	body.set_block_signals(true)
	body.sprite_frames = _validated_frames(data.get("body"), body_options[1], "Body")
	outfit.sprite_frames = _validated_frames(data.get("outfit"), outfit_options[1], "Outfit")
	hair.sprite_frames = _validated_frames(data.get("hair"), hair_options[1], "Hair")
	outfit.modulate = data.get("outfit_tint", Color.WHITE)
	body.set_block_signals(false)
	play_animation(&"idle_down")

func _validated_frames(candidate: SpriteFrames, fallback: SpriteFrames, layer_name: String) -> SpriteFrames:
	if candidate == null:
		return fallback
	for animation in REQUIRED_ANIMATIONS:
		if not candidate.has_animation(animation) or candidate.get_frame_count(animation) == 0:
			push_warning("%s: %s SpriteFrames needs nonempty '%s'; using the default layer." % [get_path(), layer_name, animation])
			return fallback
	return candidate

func play_animation(animation_name: StringName) -> void:
	body.play(animation_name)
	outfit.animation = animation_name
	hair.animation = animation_name
	_on_body_frame_changed()

func set_flip_h(value: bool) -> void:
	body.flip_h = value
	outfit.flip_h = value
	hair.flip_h = value

func _on_body_frame_changed() -> void:
	# Custom layers with shorter animations must not receive an invalid frame index.
	outfit.frame = mini(body.frame, outfit.sprite_frames.get_frame_count(outfit.animation) - 1)
	hair.frame = mini(body.frame, hair.sprite_frames.get_frame_count(hair.animation) - 1)
