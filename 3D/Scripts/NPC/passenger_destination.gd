extends Area3D

@onready var entry_point: Marker3D = $EntryPoint

@export var destination_id: StringName

var nearby_jeepney: CharacterBody3D = null

func _physics_process(_delta):
	if nearby_jeepney != null:
		if nearby_jeepney.velocity.length() <= 0.1:
			print("Jeepney stopped at destination!")
			nearby_jeepney.release_passengers(self)

			# Prevent repeated releases while the Jeepney stays inside.
			nearby_jeepney = null

func _on_body_entered(body):
	if body.is_in_group("Player"):
		print("Jeepney arrived at destination!")
		nearby_jeepney = body

func _on_body_exited(body):
	if body == nearby_jeepney:
		nearby_jeepney = null
