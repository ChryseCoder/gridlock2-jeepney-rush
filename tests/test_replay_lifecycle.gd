extends SceneTree
## Run once with -- --seed-legacy, then normally using the same disposable user data.
const LEVEL := "res://3D/Scenes/World/GameMap.tscn"
var checks := 0
var failures := 0
var session: Node
var dialogue: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func load_level() -> Node:
	change_scene_to_file(LEVEL)
	await frames(4)
	current_scene.process_mode = Node.PROCESS_MODE_DISABLED
	return current_scene

func start_ticket(level: Node) -> void:
	var player = level.get_node("Player")
	var officer = level.get_node("TrafficEnforcers/PickupEnforcer")
	officer.global_position = player.boarding_point.global_position + Vector3(1, 0, 0)
	await frames(2)
	check(session.report_illegal_stop(player, player), "enforcer claims the stop in this run")
	officer._physics_process(0.7)
	check(officer.state == officer.State.TICKETING and dialogue.is_dialog_active, "ticket starts fresh dialogue")
	check(is_instance_valid(dialogue.text_box) and dialogue.text_box.is_visible_in_tree(), "enforcer dialogue box is visible")
	check(dialogue.text_box.get_canvas_layer_node() == dialogue and dialogue.layer > level.get_node("HUD").layer, "dialogue renders on a dedicated layer above the level HUD")
	await frames(3)
	check(not dialogue.text_box.label.text.is_empty(), "ticket text animates after replay/reload")

func accept_ticket(level: Node) -> void:
	await start_ticket(level)
	for index in range(180):
		if not dialogue.is_dialog_active:
			break
		await physics_frame
	check(not dialogue.is_dialog_active, "ticket dialogue completes normally")
	level.get_node("TrafficEnforcers/PickupEnforcer")._physics_process(1.6)
	check(session.tickets == 1 and session.fines == 30000, "ticket is recorded once after its dialogue")

func run() -> void:
	Engine.time_scale = 5.0
	session = root.get_node("GameSession")
	dialogue = root.get_node("DialogueManager")
	if "--seed-legacy" in OS.get_cmdline_user_args():
		var legacy := ConfigFile.new()
		legacy.set_value("campaign", "cash", 77777)
		legacy.set_value("campaign", "points", 19)
		legacy.set_value("campaign", "fuel_penalty", true)
		var error := legacy.save("user://campaign.cfg")
		quit(0 if error == OK else 1)
		return

	check(session.cash == 10000 and session.violation_points == 0 and not session.pending_fuel_penalty, "fresh process ignores legacy disk saves and starts at ₱100 / zero violations")
	var level = await load_level()
	await accept_ticket(level)
	level.get_node("MissionManager").complete_mission()
	check(paused and session.violation_points == 1, "completion retains points until a new run or next level")
	level.get_node("HUD/LevelResults")._on_next_pressed()
	await frames(4)
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	check(session.cash == 10000 and session.violation_points == 0 and not session.pending_fuel_penalty, "Drive again resets cash, fines, points, and penalty")
	await accept_ticket(level)

	# A real configured next-level transition must keep campaign progress.
	level.get_node("MissionManager").next_level_scene = LEVEL
	level.get_node("MissionManager").complete_mission()
	level.get_node("HUD/LevelResults")._on_next_pressed()
	await frames(4)
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	check(session.cash == 0 and session.violation_points == 1 and level.get_node("Player").fuel == 75.0, "Next level keeps points, remaining cash, and fuel penalty within the run")
	await start_ticket(level)
	var discarded_box = dialogue.text_box
	level.get_node("HUD/PauseMenu")._on_retry_button_pressed()
	await frames(4)
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	check(not is_instance_valid(discarded_box) and not dialogue.is_dialog_active, "retry removes the old dialogue and resets playback state")
	check(session.violation_points == 1 and level.get_node("Player").fuel == 75.0, "retry restores the level's opening progress")
	await accept_ticket(level)

	# Returning to the menu and pressing Play starts a fresh campaign.
	level.get_node("HUD/PauseMenu")._on_main_menu_button_pressed()
	await frames(4)
	current_scene._on_play_button_pressed()
	await frames(4)
	level = current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	check(session.cash == 10000 and session.violation_points == 0, "main-menu Play starts a fresh run")
	await accept_ticket(level)

	# Cancellation must invalidate both callbacks and the inter-dialogue gap.
	dialogue.cancel_dialogue()
	var old_generation: int = dialogue._generation
	var lines: Array[String] = ["New dialogue"]
	dialogue.start_dialog(Vector2.ZERO, lines)
	dialogue._on_text_box_finished_displaying(old_generation - 1)
	check(dialogue._line_hold_left < 0.0, "stale completion callbacks cannot advance replacement dialogue")
	dialogue.cancel_dialogue()
	lines = ["A"]
	dialogue.start_dialog(Vector2.ZERO, lines)
	for index in range(120):
		if dialogue._gap_left >= 0.0:
			break
		await physics_frame
	dialogue.start_dialog(Vector2.ZERO, ["Queued after gap"] as Array[String])
	await frames(4)
	check(dialogue.is_dialog_active and is_instance_valid(dialogue.text_box), "new dialogue queued during the gap still appears")
	dialogue.cancel_dialogue()
	var legacy := ConfigFile.new()
	check(legacy.load("user://campaign.cfg") == OK and legacy.get_value("campaign", "points") == 19, "completed runs do not write campaign data to disk")
	paused = false
	current_scene.free()
	current_scene = null
	await frames(2)
	print("CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
