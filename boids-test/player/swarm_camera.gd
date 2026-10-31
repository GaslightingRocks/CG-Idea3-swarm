class_name SwarmCamera
extends Camera2D

## Follows the center of mass of a flock with a slight delay, so the view doesn't jerk.
## The zoom is set with the normal Camera2D "Zoom" property in the inspector.

# flock whose center the camera follows
@export var flock: Flock
# how quickly the camera catches up with the flock (higher = snappier, lower = smoother)
@export var follow_speed: float = 3.0


func _ready() -> void:
	global_position = flock.get_center()


func _process(delta: float) -> void:
	# Moves a fraction of the remaining distance each frame, independent of the frame rate
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(flock.get_center(), weight)
