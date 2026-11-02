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
# how quickly a shake fades out (higher = shorter)
@export var shake_fade: float = 10.0

# current shake strength in pixels, set by shake() and fading out over time
var shake_strength: float = 0.0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	global_position = flock.center


func _physics_process(delta: float) -> void:
	# Moves a fraction of the remaining distance each step, independent of the frame rate
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(flock.center, weight)


func _process(delta: float) -> void:
	# The shake only moves the view (offset), not the camera itself, so following stays smooth
	shake_strength *= exp(-shake_fade * delta)
	if shake_strength < 0.1:
		shake_strength = 0.0
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_strength


## Shakes the view for a moment, e.g. when the attack hits a hunter. Stronger shakes replace weaker ones.
func shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, strength)
