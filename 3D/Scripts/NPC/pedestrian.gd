extends CharacterBody3D
## Ambient walker: no boarding areas, mission flags, fares, or enforcement hooks.
@export_range(0.1, 5.0, 0.1) var walk_speed: float = 1.5
@export_range(0.0, 10.0, 0.1) var endpoint_pause: float = 1.0
@export_group("Appearance")
@export var randomize_appearance: bool = true
@export var body_sprite_frames: SpriteFrames
@export var outfit_sprite_frames: SpriteFrames
@export var hair_sprite_frames: SpriteFrames
@export var outfit_tint: Color = Color.WHITE

@onready var visual = $PassengerVisual
var _points := PackedVector3Array()
var _target_index := 0
var _direction := 1
var _pause_left := 0.0
var _blocked_time := 0.0
var _height := 0.0
var simulation_active := false

func _ready() -> void:
	add_to_group("AmbientPedestrians")
	visual.configure_appearance(randomize_appearance, body_sprite_frames, outfit_sprite_frames, hair_sprite_frames, outfit_tint)
	set_simulation_active(false)

func configure(points: PackedVector3Array, start_index: int, direction: int) -> void:
	_points = points
	_direction = direction
	global_position = points[start_index]
	_height = global_position.y
	_target_index = clampi(start_index + direction, 0, points.size() - 1)

func set_simulation_active(active: bool) -> void:
	simulation_active = active
	visible = active
	# Disable the whole subtree, including AnimatedSprite3D animation processing.
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if not active:
		velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _points.size() < 2:
		return
	if _pause_left > 0.0:
		_pause_left = maxf(0.0, _pause_left - delta)
		visual.play_animation(&"idle_down")
		return
	var offset := _points[_target_index] - global_position
	offset.y = 0.0
	if offset.length() < 0.06:
		if _target_index == 0 or _target_index == _points.size() - 1:
			_direction *= -1
			_pause_left = endpoint_pause
		_target_index = clampi(_target_index + _direction, 0, _points.size() - 1)
		return
	var animation := &"walk_down"
	if absf(offset.x) > absf(offset.z):
		animation = &"walk_right" if offset.x > 0.0 else &"walk_left"
	elif offset.z < 0.0:
		animation = &"walk_up"
	visual.play_animation(animation)
	velocity = offset.normalized() * minf(walk_speed, offset.length() / maxf(delta, 0.001))
	var previous := global_position
	move_and_slide()
	global_position.y = _height
	if global_position.distance_squared_to(previous) < 0.00001:
		_blocked_time += delta
	else:
		_blocked_time = 0.0
	if _blocked_time > 1.5:
		# Wait/reverse rather than pushing indefinitely into a wall or vehicle.
		_direction *= -1
		_target_index = clampi(_target_index + _direction * 2, 0, _points.size() - 1)
		_pause_left = endpoint_pause
		_blocked_time = 0.0
