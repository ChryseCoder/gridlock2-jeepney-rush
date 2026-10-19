extends Area3D

@export_range(0.0, 100.0, 1.0)
var refuel_rate: float = 10.0


func _ready() -> void:
	add_to_group("RefuelingAreas")


func try_refuel(vehicle: CharacterBody3D, delta: float) -> bool:
	if get_tree().paused or not monitoring or delta <= 0.0:
		return false

	if not (
		vehicle.is_in_group("Player")
		or vehicle.is_in_group("player")
	):
		return false

	if not overlaps_body(vehicle) or not vehicle.has_method("refuel"):
		return false

	return vehicle.refuel(refuel_rate * delta) > 0.0
