class_name SwarmCamera
extends Camera2D

## Follows the center of mass of a flock with a slight delay, so the view doesn't jerk.
## The zoom is set with the normal Camera2D "Zoom" property in the inspector.
## Moves in the physics step like the boids: with physics interpolation (Project Settings > Physics > Common)
## Godot then smooths both between physics steps, so boids and camera don't jitter against each other.

# flock whose center the camera follows
@export var flock: Flock
# how quickly the camera catches up with the flock (higher = snappier, lower = smoother)
@export var follow_speed: float = 3.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	global_position = flock.center


func _physics_process(delta: float) -> void:
	# Moves a fraction of the remaining distance each step, independent of the frame rate
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(flock.center, weight)
