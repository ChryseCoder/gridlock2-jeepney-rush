extends Path3D
## Draw a level sidewalk path; its parent PedestrianSystem populates it once.
@export_range(0, 20, 1) var pedestrian_count: int = 4
@export_range(0.1, 5.0, 0.1) var minimum_speed: float = 1.0
@export_range(0.1, 5.0, 0.1) var maximum_speed: float = 1.8
@export_range(0.0, 10.0, 0.1) var endpoint_pause: float = 1.0
