extends SceneTree

const PASSENGER := "res://3D/Scenes/NPC/Passenger.tscn"
const ENFORCER := "res://3D/Scenes/NPC/TrafficEnforcer.tscn"
const BODY := preload("res://3D/Assets/Images/Sprites/Passengers/body_01.tres")
const OUTFIT := preload("res://3D/Assets/Images/Sprites/Passengers/outfit_03.tres")
const HAIR := preload("res://3D/Assets/Images/Sprites/Passengers/hair_01.tres")
const CUSTOM_TINT := Color(0.8, 0.3, 0.2)
var failures := 0
var checks := 0
var fixture: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func fixed_npc(scene_path: String, tint: Color) -> CharacterBody3D:
	var npc = load(scene_path).instantiate()
	npc.randomize_appearance = false
	npc.body_sprite_frames = BODY
	npc.outfit_sprite_frames = OUTFIT
	npc.hair_sprite_frames = HAIR
	npc.outfit_tint = tint
	fixture.add_child(npc)
	npc.set_physics_process(false)
	return npc

func inspector_has_appearance(npc: Node) -> bool:
	var in_group := false
	var count := 0
	for property in npc.get_property_list():
		if property.usage & PROPERTY_USAGE_GROUP:
			in_group = property.name == "Appearance"
		elif in_group and property.usage & PROPERTY_USAGE_EDITOR:
			if property.name in ["randomize_appearance", "body_sprite_frames", "outfit_sprite_frames", "hair_sprite_frames", "outfit_tint"]:
				count += 1
	return count == 5

func run() -> void:
	Engine.time_scale = 5.0
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var passenger = fixed_npc(PASSENGER, CUSTOM_TINT)
	var officer = fixed_npc(ENFORCER, Color(0.1, 0.8, 0.4))
	check(inspector_has_appearance(passenger) and inspector_has_appearance(officer), "both CharacterBody3D roots expose all five Appearance fields")
	for npc in [passenger, officer]:
		var visual = npc.get_node("PassengerVisual")
		check(visual.body.sprite_frames == BODY and visual.outfit.sprite_frames == OUTFIT and visual.hair.sprite_frames == HAIR, "fixed resources are applied on startup for " + npc.name)
		check(visual.outfit.modulate == npc.outfit_tint, "root Outfit Tint is respected for " + npc.name)
		visual.play_animation(&"walk_right")
		check(visual.body.is_playing() and visual.body.animation == &"walk_right" and visual.outfit.animation == &"walk_right" and visual.hair.animation == &"walk_right", "custom layers still animate together for " + npc.name)
	check(passenger.visual.outfit.modulate != officer.visual.outfit.modulate and passenger.visual.outfit.sprite_frames == officer.visual.outfit.sprite_frames, "per-instance tint does not alter shared SpriteFrames")
	var packed := PackedScene.new()
	check(packed.pack(officer) == OK, "appearance overrides can be serialized in a scene")
	var restored = packed.instantiate()
	fixture.add_child(restored)
	restored.set_physics_process(false)
	check(restored.randomize_appearance == false and restored.visual.body.sprite_frames == BODY and restored.visual.outfit.modulate == officer.outfit_tint, "saved scene instances retain their Inspector appearance overrides")

	var defaults = load(ENFORCER).instantiate()
	fixture.add_child(defaults)
	defaults.set_physics_process(false)
	check(defaults.randomize_appearance and defaults.visual.outfit.modulate == Color(0.2, 0.45, 1.0), "existing enforcers keep randomized sprites and their blue tint")
	var fallback = load(PASSENGER).instantiate()
	fallback.randomize_appearance = false
	fixture.add_child(fallback)
	fallback.set_physics_process(false)
	check(fallback.visual.body.sprite_frames == fallback.visual.body_options[1] and fallback.visual.hair.sprite_frames == fallback.visual.hair_options[1], "empty fixed slots use stable default layers")

	# A shorter custom layer is clamped to its valid frame count.
	var short_hair: SpriteFrames = HAIR.duplicate()
	var original_count := HAIR.get_frame_count(&"walk_right")
	for animation in short_hair.get_animation_names():
		while short_hair.get_frame_count(animation) > 1:
			short_hair.remove_frame(animation, short_hair.get_frame_count(animation) - 1)
	fallback.visual.configure_appearance(false, BODY, OUTFIT, short_hair, Color.WHITE)
	fallback.visual.play_animation(&"walk_right")
	fallback.visual.body.frame = mini(2, BODY.get_frame_count(&"walk_right") - 1)
	fallback.visual._on_body_frame_changed()
	check(fallback.visual.hair.frame == 0 and HAIR.get_frame_count(&"walk_right") == original_count, "short custom animations stay in bounds without modifying source resources")
	fallback.visual.configure_appearance(false, SpriteFrames.new(), OUTFIT, HAIR, Color.WHITE)
	check(fallback.visual.body.sprite_frames == fallback.visual.body_options[1], "missing required animations safely fall back to the default body")

	# Exercise the real passenger manifest and disembarkation path, including tint.
	var player = load("res://3D/Scenes/Player/Player.tscn").instantiate()
	player.passenger_scene = load(PASSENGER)
	fixture.add_child(player)
	player.set_physics_process(false)
	passenger.destination_id = &"Appearance Test"
	passenger.jeepney = player
	passenger.walking = true
	passenger.board_jeepney()
	var manifest: Dictionary = player.passengers[0]["appearance"]
	check(manifest.body == BODY and manifest.outfit == OUTFIT and manifest.hair == HAIR and manifest.outfit_tint == CUSTOM_TINT, "boarding stores all selected layers and tint")
	root.get_node("DialogueManager").cancel_dialogue()
	await process_frame
	var destination = load("res://3D/Scenes/NPC/PassengerDestination.tscn").instantiate()
	destination.destination_id = &"Appearance Test"
	destination.position = Vector3(15, 0, 0)
	fixture.add_child(destination)
	player.release_passengers(destination)
	var released: Node = null
	for child in fixture.get_children():
		if child.has_method("prepare_disembarkation") and child.walking_to_destination:
			released = child
	check(released != null, "real drop-off spawns the disembarking passenger")
	if released:
		released.set_physics_process(false)
		var appearance: Dictionary = released.visual.get_appearance()
		check(appearance.body == BODY and appearance.outfit == OUTFIT and appearance.hair == HAIR and appearance.outfit_tint == CUSTOM_TINT, "drop-off preserves the passenger's fixed sprites and custom tint")
		check(released.visual.body.is_playing(), "restored passenger animations remain active")
	await create_timer(0.7).timeout
	fixture.free()
	current_scene = null
	await process_frame
	print("CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
