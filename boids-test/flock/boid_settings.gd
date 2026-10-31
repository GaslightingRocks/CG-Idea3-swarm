class_name BoidSettings
extends Resource

## Tuning values shared by all boids. Changing a value at runtime affects every boid using this resource.
## Every @export_range property automatically gets a slider in the BoidSettingsPanel.
## The values below are the defaults, a .tres file (e.g. default_boid_settings.tres) can override them.

# constant movement speed (pixels per physics frame)
@export_range(0.5, 15.0, 0.1) var speed: float = 5.0
# max change of velocity per physics frame, lower = smoother but wider turns
@export_range(0.01, 3.0, 0.01) var max_steer_force: float = 0.5
# how strongly the boid matches the flight direction of its neighbors
@export_range(0.0, 5.0, 0.05) var alignment_weight: float = 1.0
# how strongly the boid moves toward the center of mass of its neighbors
@export_range(0.0, 5.0, 0.05) var cohesion_weight: float = 1.0
# gentle, permanent pull toward the center of the whole flock, keeps groups from drifting apart for good
@export_range(0.0, 2.0, 0.01) var flock_pull_weight: float = 0.15
# how strongly the boid keeps its personal space free
@export_range(0.0, 5.0, 0.05) var separation_weight: float = 2.0
# personal space (in pixels): only neighbors closer than this push the boid away
@export_range(16.0, 100.0, 1.0) var separation_radius: float = 28.0
# how strongly the boid follows the mouse force of the player
@export_range(0.0, 10.0, 0.1) var player_influence_weight: float = 2.0
# how strongly the boid turns away from walls detected by its raycasts
@export_range(0.0, 10.0, 0.1) var wall_avoidance_weight: float = 4.0
# radius (in pixels) in which a boid sees its neighbors (for alignment and cohesion)
@export_range(20.0, 300.0, 1.0) var vision_radius: float = 90.0
# length (in pixels) of the forward ray, the side rays get shorter toward the edges
@export_range(10.0, 200.0, 1.0) var wall_look_ahead: float = 64.0
# angle (in degrees) between the forward ray and the outermost side ray
@export_range(10.0, 90.0, 1.0) var wall_ray_spread: float = 60.0
# if true, a boid touching a wall is lost; if false, it slides along the wall (handy for tuning)
@export var lethal_walls: bool = true
# how fast the rotation follows the velocity (0 = never, 1 = instantly)
@export_range(0.0, 1.0, 0.01) var rotation_smoothing: float = 0.4
