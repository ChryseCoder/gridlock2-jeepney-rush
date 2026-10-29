extends Node
## Campaign state survives scene changes; completed runs are saved to disk.
signal changed
signal enforcement_notice(message: String)

const SAVE_PATH := "user://campaign.cfg"
const STARTING_CASH := 10000 # All money is stored as integer centavos.
const FARE := 1500
const TICKET_FINE := 30000

var cash: int = STARTING_CASH
var violation_points: int = 0
var pending_fuel_penalty: bool = false
var earnings: int = 0
var fuel_spending: int = 0
var fines: int = 0
var tickets: int = 0
var evasions: int = 0
var delivered: int = 0
var level_active := false
var last_results: Dictionary = {}
var _fuel_cost_exact: float = 0.0
var _opening_cash: int = STARTING_CASH
var _opening_points: int = 0
var _opening_penalty := false
var _active_encounters: Dictionary = {}

func _ready() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) == OK:
		cash = maxi(0, int(save.get_value("campaign", "cash", STARTING_CASH)))
		violation_points = maxi(0, int(save.get_value("campaign", "points", 0)))
		pending_fuel_penalty = bool(save.get_value("campaign", "fuel_penalty", false))

func begin_level() -> void:
	# Reloading an unfinished level restores its opening state, preventing farming.
	if level_active:
		cash = _opening_cash
		violation_points = _opening_points
		pending_fuel_penalty = _opening_penalty
	_opening_cash = cash
	_opening_points = violation_points
	_opening_penalty = pending_fuel_penalty
	earnings = 0
	fuel_spending = 0
	_fuel_cost_exact = 0.0
	fines = 0
	tickets = 0
	evasions = 0
	delivered = 0
	last_results.clear()
	_active_encounters.clear()
	level_active = true
	changed.emit()

func starting_fuel_multiplier() -> float:
	return 0.75 if _opening_penalty else 1.0

func award_fare() -> void:
	if not level_active:
		return
	earnings += FARE
	cash += FARE
	delivered += 1
	changed.emit()

func buy_fuel(vehicle: CharacterBody3D, requested: float, price: int) -> float:
	if not level_active or requested <= 0.0 or price <= 0 or cash <= 0:
		return 0.0
	var affordable := minf(requested, float(cash) / price)
	var actual: float = vehicle.refuel(affordable)
	if actual <= 0.0:
		return 0.0
	# Charge only for fuel actually added (including the last partial tank).
	_fuel_cost_exact += actual * price
	var cost := mini(cash, maxi(0, ceili(_fuel_cost_exact - 0.00001) - fuel_spending))
	cash -= cost
	fuel_spending += cost
	changed.emit()
	return actual

func report_illegal_stop(vehicle: CharacterBody3D, spot: Node3D) -> bool:
	if not level_active or get_tree().paused:
		return false
	var vehicle_id := vehicle.get_instance_id()
	if _active_encounters.has(vehicle_id):
		return false
	var nearest: Node3D = null
	var nearest_distance := INF
	for enforcer in get_tree().get_nodes_in_group("TrafficEnforcers"):
		if enforcer.can_witness(vehicle, spot):
			var distance: float = enforcer.global_position.distance_squared_to(vehicle.global_position)
			if distance < nearest_distance:
				nearest = enforcer
				nearest_distance = distance
	if nearest == null:
		return false
	_active_encounters[vehicle_id] = nearest
	nearest.begin_encounter(vehicle)
	return true

func resolve_encounter(vehicle_id: int, enforcer: Node, evaded: bool) -> bool:
	if not level_active or _active_encounters.get(vehicle_id) != enforcer:
		return false
	_active_encounters.erase(vehicle_id)
	if evaded:
		evasions += 1
		violation_points += 2
		enforcement_notice.emit("Enforcer evaded: +2 violation points")
	else:
		tickets += 1
		fines += TICKET_FINE
		violation_points += 1
		enforcement_notice.emit("Ticket: ₱300 due at completion · +1 violation point")
	changed.emit()
	return true

func abandon_encounter(vehicle_id: int, enforcer: Node) -> void:
	if _active_encounters.get(vehicle_id) == enforcer:
		_active_encounters.erase(vehicle_id)

func has_active_encounters() -> bool:
	return not _active_encounters.is_empty()

func finish_level() -> Dictionary:
	if not level_active:
		return last_results.duplicate()
	var paid := mini(cash, fines)
	var unpaid := fines - paid
	cash -= paid
	pending_fuel_penalty = unpaid > 0
	last_results = {
		"starting_cash": _opening_cash, "earnings": earnings,
		"fuel_spending": fuel_spending, "fines": fines, "paid_fines": paid,
		"unpaid_fines": unpaid, "net_income": earnings - fuel_spending - fines,
		"cash": cash, "violation_points": violation_points,
		"level_points": violation_points - _opening_points,
		"tickets": tickets, "evasions": evasions, "delivered": delivered,
		"fuel_penalty": pending_fuel_penalty
	}
	level_active = false
	_active_encounters.clear()
	_save_campaign()
	changed.emit()
	return last_results.duplicate()

func _save_campaign() -> void:
	var save := ConfigFile.new()
	save.set_value("campaign", "cash", cash)
	save.set_value("campaign", "points", violation_points)
	save.set_value("campaign", "fuel_penalty", pending_fuel_penalty)
	var error := save.save(SAVE_PATH)
	if error != OK:
		push_warning("Campaign progress could not be saved: %s" % error)

func money(centavos: int) -> String:
	return "₱%s%.2f" % ["-" if centavos < 0 else "", absf(centavos) / 100.0]
