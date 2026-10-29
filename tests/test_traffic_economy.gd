extends SceneTree
## Run with an isolated XDG_DATA_HOME to keep real campaign saves untouched.
var failures := 0
var checks := 0
var session: Node
var fixture: Node3D
var player: CharacterBody3D
var enforcer: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func frames(count: int) -> void:
	for index in range(count):
		await physics_frame

func reset_session() -> void:
	session.level_active = false
	session.cash = 10000
	session.violation_points = 0
	session.pending_fuel_penalty = false
	session.begin_level()

func make_enforcer(position: Vector3) -> CharacterBody3D:
	var npc = load("res://3D/Scenes/NPC/TrafficEnforcer.tscn").instantiate()
	npc.position = position
	npc.ticket_dialogue = "Huli ka, boss!"
	fixture.add_child(npc)
	return npc

func run() -> void:
	Engine.time_scale = 5.0
	session = root.get_node("GameSession")
	reset_session()
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	player = load("res://3D/Scenes/Player/Player.tscn").instantiate()
	fixture.add_child(player)
	player.set_physics_process(false)
	player.fuel = 50.0
	await frames(2)

	session.award_fare()
	check(session.cash == 11500 and session.earnings == 1500, "drop-off pays ₱15 on top of ₱100 starting cash")
	for frame in range(60):
		session.buy_fuel(player, 10.0 / 60.0, 200)
	check(absf(player.fuel - 60.0) < 0.001, "fuel rises continuously by actual purchased units")
	check(abs(session.fuel_spending - 2000) <= 1, "fractional refueling does not round charges every frame")
	player.speed = 2.0
	var previous_cash: int = session.cash
	check(session.buy_fuel(player, 5, 200) == 0.0 and session.cash == previous_cash, "moving vehicles cannot buy fuel")
	player.speed = 0.0
	player.fuel = player.max_fuel
	check(session.buy_fuel(player, 5, 200) == 0.0 and session.cash == previous_cash, "full tanks are not charged")
	player.fuel = 10.0
	session.cash = 37
	var added: float = session.buy_fuel(player, 100, 200)
	check(added <= 0.1851 and session.cash == 0, "last partial purchase respects available cash")
	check(session.buy_fuel(player, 1, 200) == 0.0, "no free fuel with an empty wallet")

	# Real station overlap: only one area may charge per physics update.
	reset_session()
	player.fuel = 50.0
	var station = load("res://3D/Scenes/Environment/refuelingarea.tscn").instantiate()
	fixture.add_child(station)
	var overlapping_station = load("res://3D/Scenes/Environment/refuelingarea.tscn").instantiate()
	fixture.add_child(overlapping_station)
	await frames(3)
	player._try_refuel(0.1)
	check(absf(player.fuel - 51.0) < 0.001 and session.cash == 9800, "overlapping station markers do not multiply fuel or cost")
	station.free()
	overlapping_station.free()

	reset_session()
	enforcer = make_enforcer(Vector3(5, 0, -2))
	var second := make_enforcer(Vector3(7, 0, -2))
	await frames(2)
	var wall := StaticBody3D.new()
	wall.position = Vector3(3, 0, -1)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 5, 10)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	fixture.add_child(wall)
	await frames(2)
	check(not session.report_illegal_stop(player, player), "buildings block enforcer visibility")
	wall.free()
	await frames(2)
	check(session.report_illegal_stop(player, player), "nearby enforcer witnesses an illegal stop")
	check(enforcer.state == enforcer.State.ALERT and second.state == second.State.IDLE, "nearest enforcer claims the incident")
	check(not session.report_illegal_stop(player, player), "overlapping enforcers cannot double-ticket a stop")
	var start: Vector3 = enforcer.global_position
	await frames(20)
	check(enforcer.global_position.distance_to(start) > 0.1, "enforcer walks toward the stopped vehicle")
	for frame in range(240):
		if session.tickets == 1:
			break
		await physics_frame
	check(session.tickets == 1 and session.fines == 30000 and session.violation_points == 1, "accepting a ticket adds ₱300 deferred fines and +1 point")
	check(session.cash == 10000, "ticket does not deduct cash before completion")
	for frame in range(160):
		if enforcer.state == enforcer.State.IDLE:
			break
		await physics_frame
	check(enforcer.state == enforcer.State.IDLE and enforcer.global_position.distance_to(enforcer.home_position) < 0.2, "enforcer returns to its post after ticketing")
	for attempt in range(2):
		player.global_position = Vector3.ZERO
		await frames(2)
		check(session.report_illegal_stop(player, player), "new illegal stop can trigger another encounter")
		player.global_position = Vector3(100, 0, 0)
		await frames(2)
	check(session.evasions == 2 and session.violation_points == 5 and session.fines == 30000, "repeated evasions each add +2 points without another fine")
	player.global_position = Vector3(100, 0, 100)
	await frames(2)
	check(not session.report_illegal_stop(player, player), "distant illegal stops go unwitnessed")

	var result: Dictionary = session.finish_level()
	check(result.cash == 0 and result.unpaid_fines == 20000 and result.fuel_penalty, "unaffordable fines consume available cash and apply next-level penalty")
	var again: Dictionary = session.finish_level()
	check(again == result and session.cash == 0, "settlement is idempotent")
	session.begin_level()
	check(session.violation_points == 5 and session.starting_fuel_multiplier() == 0.75, "points and 25% fuel reduction carry to the next level")
	session.award_fare()
	session.violation_points += 2
	session.begin_level()
	check(session.cash == 0 and session.violation_points == 5 and session.starting_fuel_multiplier() == 0.75, "retry restores opening cash, points, and fuel penalty")
	session.award_fare()
	session.finish_level()
	session.begin_level()
	check(session.starting_fuel_multiplier() == 1.0, "fuel penalty lasts one completed level")
	# Solvent completion deducts fines once and carries positive cash forward.
	session.level_active = false
	session.cash = 50000
	session.begin_level()
	session.fines = 30000
	session.award_fare()
	var paid_result: Dictionary = session.finish_level()
	check(paid_result.cash == 21500 and paid_result.paid_fines == 30000 and not paid_result.fuel_penalty, "solvent settlement pays full fines and preserves remaining cash")
	fixture.free()
	current_scene = null
	await frames(2)

	# Exercise real level wiring and both legal/illegal pickup and drop-off paths.
	reset_session()
	var level = load("res://3D/Scenes/World/GameMap.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	var manager = level.get_node("MissionManager")
	var game_player = level.get_node("Player")
	game_player.set_physics_process(false)
	check(manager.remaining_mission_passengers == 2, "level discovers both designated mission passengers")
	check(game_player.fuel == 100.0, "current level starts with a full tank without a penalty")
	var passenger = level.get_node("Passenger")
	var legal_passenger = level.get_node("Passenger2")
	legal_passenger.walk_to_jeepney(game_player)
	check(not session.has_active_encounters(), "legal pickup does not summon an enforcer")
	legal_passenger.cancel_boarding()
	# Move the player close to the illegal pickup; physics syncs visibility queries.
	game_player.global_position = passenger.global_position + Vector3(1, 0, 0)
	await frames(2)
	passenger.walk_to_jeepney(game_player)
	check(session.has_active_encounters(), "illegal passenger inspector setting triggers nearby enforcer")
	root.get_node("DialogueManager").cancel_dialogue()
	for npc in get_nodes_in_group("TrafficEnforcers"):
		npc.set_physics_process(false)
		session.abandon_encounter(game_player.get_instance_id(), npc)
	# Actual drop-off removes the manifest entry and pays exactly once.
	passenger.set_physics_process(false)
	legal_passenger.set_physics_process(false)
	game_player.global_position = level.get_node("Destination2").global_position
	await frames(2)
	game_player.add_passenger(&"School", passenger.visual.get_appearance(), true)
	var cash_before: int = session.cash
	game_player.release_passengers(level.get_node("Destination2"))
	check(session.has_active_encounters() and level.get_node("TrafficEnforcers/SchoolEnforcer").state == 1, "illegal destination inspector setting summons the school enforcer")
	check(session.cash == cash_before + 1500 and game_player.passenger_count == 0, "real drop-off pays once and removes passenger from manifest")
	game_player.release_passengers(level.get_node("Destination2"))
	check(session.cash == cash_before + 1500, "duplicate drop-off cannot award another fare")
	# An outstanding encounter must block results, then completion settles once.
	session._active_encounters[game_player.get_instance_id()] = level.get_node("TrafficEnforcers/PickupEnforcer")
	manager.passenger_arrived()
	manager.passenger_arrived()
	manager._process(0.1)
	check(not manager.mission_completed, "final delivery waits for active enforcement")
	session._active_encounters.clear()
	root.get_node("DialogueManager").cancel_dialogue()
	manager._process(0.1)
	check(manager.mission_completed and paused and level.get_node("HUD/LevelResults").visible, "all mission deliveries open the new results screen and pause gameplay")
	level.get_node("HUD/PauseMenu")._unhandled_input(InputEventAction.new())
	check(paused, "pause menu cannot resume gameplay behind results")
	paused = false
	# Allow the disembarkation coroutine to finish before freeing its scene.
	await create_timer(0.7).timeout
	level.free()
	current_scene = null
	root.get_node("DialogueManager").cancel_dialogue()
	await create_timer(2.0).timeout
	await frames(2)
	print("CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
