extends Camera3D

@export var target: Node3D
@export var height: float = 10.0
@export var follow_speed: float = 5.0

func _physics_process(delta: float) -> void:
	if not target:
		return

	var desired_position = Vector3(
		target.global_position.x,
		height,
		target.global_position.z
	)

	global_position = global_position.lerp(
		desired_position,
		follow_speed * delta
	)
