extends MeshInstance3D

@export var bob_height: float = 0.02
@export var bob_speed: float = 2.0
@export var pulse_amount: float = 0.04
@export var pulse_speed: float = 2.5

var start_y: float
var start_scale: Vector3
var time := 0.0


func _ready():
	start_y = position.y
	start_scale = scale


func _process(delta):
	time += delta

	position.y = start_y + sin(time * bob_speed) * bob_height

	var pulse = 1.0 + sin(time * pulse_speed) * pulse_amount
	scale = start_scale * pulse
