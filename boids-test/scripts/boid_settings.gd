class_name BoidSettings
extends Resource

## Tuning values shared by all boids. Changing a value at runtime affects every boid using this resource.
## Every @export_range property automatically gets a slider in the BoidSettingsPanel.

# constant movement speed (pixels per physics frame)
@export_range(0.5, 15.0, 0.1) var speed: float = 5.0
# max change of velocity per physics frame, lower = smoother but wider turns
@export_range(0.01, 3.0, 0.01) var max_steer_force: float = 0.5
# how strongly the boid matches the flight direction of its neighbors
@export_range(0.0, 5.0, 0.05) var alignment_weight: float = 1.0
# how strongly the boid moves toward the center of mass of its neighbors
@export_range(0.0, 5.0, 0.05) var cohesion_weight: float = 0.8
# how strongly the boid keeps distance from its neighbors
@export_range(0.0, 5.0, 0.05) var separation_weight: float = 1.5
# how strongly the boid turns away from walls detected by its raycasts
@export_range(0.0, 10.0, 0.1) var wall_avoidance_weight: float = 4.0
# how fast the rotation follows the velocity (0 = never, 1 = instantly)
@export_range(0.0, 1.0, 0.01) var rotation_smoothing: float = 0.4
