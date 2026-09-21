extends Node3D
class_name TrafficLight


@export_group("Light Meshes")

@export var red_lens: MeshInstance3D
@export var yellow_lens: MeshInstance3D
@export var green_lens: MeshInstance3D


@export_group("Emission")

@export var active_energy: float = 4.0
@export var inactive_energy: float = 0.05


var current_state: TrafficManager.LightState = TrafficManager.LightState.RED

var red_material: StandardMaterial3D
var yellow_material: StandardMaterial3D
var green_material: StandardMaterial3D


func _ready() -> void:
	_prepare_materials()

	set_state(current_state)


func _prepare_materials() -> void:
	red_material = _get_material_copy(red_lens)
	yellow_material = _get_material_copy(yellow_lens)
	green_material = _get_material_copy(green_lens)

	_setup_emission(
		red_material,
		Color(1.0, 0.02, 0.02)
	)

	_setup_emission(
		yellow_material,
		Color(1.0, 0.65, 0.02)
	)

	_setup_emission(
		green_material,
		Color(0.02, 1.0, 0.1)
	)


func _get_material_copy(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance == null:
		return null

	var material: Material = mesh_instance.get_active_material(0)

	if material == null:
		return null

	var copied_material = material.duplicate()

	mesh_instance.set_surface_override_material(
		0,
		copied_material
	)

	return copied_material as StandardMaterial3D


func _setup_emission(
	material: StandardMaterial3D,
	color: Color
) -> void:

	if material == null:
		return

	material.emission_enabled = true
	material.emission = color


func set_state(
	new_state: TrafficManager.LightState
) -> void:

	current_state = new_state

	match current_state:

		TrafficManager.LightState.RED:
			_set_light_energy(
				active_energy,
				inactive_energy,
				inactive_energy
			)

		TrafficManager.LightState.YELLOW:
			_set_light_energy(
				inactive_energy,
				active_energy,
				inactive_energy
			)

		TrafficManager.LightState.GREEN:
			_set_light_energy(
				inactive_energy,
				inactive_energy,
				active_energy
			)


func _set_light_energy(
	red_energy: float,
	yellow_energy: float,
	green_energy: float
) -> void:

	if red_material:
		red_material.emission_energy_multiplier = red_energy

	if yellow_material:
		yellow_material.emission_energy_multiplier = yellow_energy

	if green_material:
		green_material.emission_energy_multiplier = green_energy
