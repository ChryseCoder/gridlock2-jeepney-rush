extends Node

# TrafficManager.gd
# Add this script as an Autoload named "TrafficManager".

signal intersection_registered(intersection)
signal intersection_unregistered(intersection)

# We'll use this later for the player.
signal red_light_violation(vehicle, intersection, approach)

var traffic_enabled: bool = true
var intersections: Array[Node] = []

enum LightState {
	RED,
	YELLOW,
	GREEN
}

func register_intersection(intersection: Node) -> void:
	if intersection == null:
		return

	if intersection not in intersections:
		intersections.append(intersection)
		intersection_registered.emit(intersection)


func unregister_intersection(intersection: Node) -> void:
	if intersection in intersections:
		intersections.erase(intersection)
		intersection_unregistered.emit(intersection)


func report_red_light_violation(
	vehicle: Node,
	intersection: Node,
	approach: StringName
) -> void:
	# For now, only report the event.
	# Later this can deduct time, score, money, etc.
	red_light_violation.emit(vehicle, intersection, approach)

	print(
		"Red light violation at ",
		intersection.name,
		" from direction: ",
		approach
	)


func set_traffic_enabled(enabled: bool) -> void:
	traffic_enabled = enabled


func get_intersections() -> Array[Node]:
	return intersections
