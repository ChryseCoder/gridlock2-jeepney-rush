extends CharacterBody3D

@export var walk_speed: float = 2.0
@export var boarding_distance: float = 0.5
@export var max_boarding_distance: float = 3.0

@onready var visual = $PassengerVisual

var jeepney: CharacterBody3D
var walking: bool = false

var destination_target: Vector3
var walking_to_destination: bool = false
var can_board: bool = true
var nearby_jeepney: CharacterBody3D = null

func _ready():
	visual.play_animation("idle_down")


func walk_to_jeepney(target_jeepney: CharacterBody3D):
	jeepney = target_jeepney
	walking = true
	walking_to_destination = false


func walk_to_destination(target_position: Vector3):
	destination_target = target_position
	walking = true
	walking_to_destination = true
	can_board = false

func _physics_process(_delta):
	
	if walking and not walking_to_destination and jeepney != null:
		var distance_to_jeepney = global_position.distance_to(jeepney.boarding_point.global_position)

		if distance_to_jeepney > max_boarding_distance:
			cancel_boarding()
			return
	
	if not walking and nearby_jeepney != null:
		if nearby_jeepney.velocity.length() <= 0.1:
			print("Jeepney stopped. Passenger boarding!")
			walk_to_jeepney(nearby_jeepney)
	
	if not walking:
		velocity = Vector3.ZERO
		return

	var target_position: Vector3

	if walking_to_destination:
		target_position = destination_target
	else:
		if jeepney == null:
			return

		target_position = jeepney.boarding_point.global_position

	var direction = target_position - global_position
	direction.y = 0.0

	if direction.length() <= boarding_distance:
		if walking_to_destination:
			reach_destination()
		else:
			board_jeepney()

		return

	direction = direction.normalized()

	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	update_walk_animation(direction)

	move_and_slide()


func update_walk_animation(direction: Vector3):
	if abs(direction.x) > abs(direction.z):

		if direction.x > 0:
			visual.play_animation("walk_right")
		else:
			visual.play_animation("walk_left")

	else:
		if direction.z > 0:
			visual.play_animation("walk_down")
		else:
			visual.play_animation("walk_up")


func board_jeepney():
	if not walking:
		return

	walking = false
	velocity = Vector3.ZERO

	jeepney.add_passenger()

	queue_free()


func reach_destination():
	walking = false
	velocity = Vector3.ZERO

	print("Passenger reached destination!")

	queue_free()


func _on_area_3d_body_entered(body):
	if not can_board:
		return

	if body.is_in_group("player"):
		print("Jeepney detected!")
		nearby_jeepney = body

func _on_area_3d_body_exited(body):
	if body == nearby_jeepney:
		nearby_jeepney = null


func cancel_boarding():
	walking = false
	velocity = Vector3.ZERO
	jeepney = null

	visual.play_animation("idle_down")
	print("Boarding cancelled. Jeepney moved too far away.")
