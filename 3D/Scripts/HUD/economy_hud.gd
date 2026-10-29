extends PanelContainer

@onready var balance: Label = $Margin/Column/Balance
@onready var ledger: Label = $Margin/Column/Ledger
@onready var objectives: Label = $Margin/Column/Objectives
@onready var fuel_status: Label = $Margin/Column/FuelStatus
@onready var notice: Label = $Margin/Column/Notice
var _notice_time := 0.0

func _ready() -> void:
	GameSession.changed.connect(_refresh)
	GameSession.enforcement_notice.connect(_show_notice)
	_refresh()

func _refresh() -> void:
	balance.text = "CASH  %s" % GameSession.money(GameSession.cash)
	ledger.text = "Fines due  %s    •    Violations  %d" % [GameSession.money(GameSession.fines), GameSession.violation_points]

func _show_notice(message: String) -> void:
	notice.text = message
	notice.show()
	_notice_time = 6.0

func _process(delta: float) -> void:
	var manager = get_tree().get_first_node_in_group("MissionManager")
	if manager:
		objectives.text = "Mission passengers remaining: %d" % manager.remaining_mission_passengers
	_update_fuel_status()
	_notice_time = maxf(0.0, _notice_time - delta)
	if _notice_time <= 0.0:
		notice.hide()

func _update_fuel_status() -> void:
	fuel_status.hide()
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	for area in get_tree().get_nodes_in_group("RefuelingAreas"):
		if area.overlaps_body(player):
			var action := "Refueling" if player.is_stopped_for_refueling() else "Stop to refuel"
			if player.fuel >= player.max_fuel:
				action = "Tank full"
			elif GameSession.cash == 0:
				action = "No cash for fuel"
			fuel_status.text = "%s · %s / fuel unit" % [action, GameSession.money(area.price_per_fuel_unit)]
			fuel_status.show()
			return
