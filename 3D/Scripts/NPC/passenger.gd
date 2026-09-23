extends CharacterBody3D

@export var walk_speed: float = 2.0
@export var boarding_distance: float = 0.5
@export var max_boarding_distance: float = 3.0
@export var destination_id: StringName

@onready var visual = $PassengerVisual

var jeepney: CharacterBody3D
var walking: bool = false

var destination_target: Vector3
var walking_to_destination: bool = false
var can_board: bool = true
var nearby_jeepney: CharacterBody3D = null

var waiting_position: Vector3
var returning_to_wait: bool = false

func _ready():
	waiting_position = global_position
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

	# Cancel boarding if the Jeepney drives too far away.
	if walking and not walking_to_destination and not returning_to_wait and jeepney != null:
		var distance_to_jeepney = global_position.distance_to(
			jeepney.boarding_point.global_position
		)

		if distance_to_jeepney > max_boarding_distance:
			cancel_boarding()
			return


	# Start boarding once the nearby Jeepney stops.
	if not walking and nearby_jeepney != null:
		if nearby_jeepney.velocity.length() <= 0.1:
			print("Jeepney stopped. Passenger boarding!")
			walk_to_jeepney(nearby_jeepney)


	if not walking:
		velocity = Vector3.ZERO
		return


	# Decide where the passenger should walk.
	var target_position: Vector3

	if returning_to_wait:
		target_position = waiting_position

	elif walking_to_destination:
		target_position = destination_target

	else:
		if jeepney == null:
			return

		target_position = jeepney.boarding_point.global_position


	# Calculate direction AFTER choosing the target.
	var direction = target_position - global_position
	direction.y = 0.0


	# Only board / disappear once the target is actually reached.
	if direction.length() <= boarding_distance:

		if returning_to_wait:
			returning_to_wait = false
			walking = false
			velocity = Vector3.ZERO
			visual.play_animation("idle_down")

		elif walking_to_destination:
			reach_destination()

		else:
			board_jeepney()

		return


	# Walk toward the target.
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

	jeepney.add_passenger(
	destination_id,
	visual.get_appearance()
)
	
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
	jeepney = null
	walking = true
	returning_to_wait = true

	print("Boarding cancelled. Returning to waiting position.")
