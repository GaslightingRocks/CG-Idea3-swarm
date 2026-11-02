class_name PlayerInfluence
extends Node

## Turns the mouse into a steering force for a flock.
## The direction from the screen center to the mouse gives the direction of the force,
## the strength is the same everywhere and is changed with the mouse wheel.
## Since the camera follows the swarm, the screen center is roughly where the swarm is.

# mouse distance (in screen pixels) from the screen center below which there's no force,
# so the swarm can fly on its own when the mouse rests on it
@export var dead_zone: float = 30.0
# strength at the start of a round (0 = no force, 1 = full force)
@export_range(0.0, 1.0, 0.05) var start_strength: float = 0.6
# how much one mouse wheel step changes the strength
@export_range(0.01, 0.5, 0.01) var wheel_step: float = 0.1

# current strength between 0 and 1, changed with the mouse wheel
var strength: float = 0.0


func _ready() -> void:
	strength = start_strength


func _unhandled_input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		strength = clampf(strength + wheel_step, 0.0, 1.0)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		strength = clampf(strength - wheel_step, 0.0, 1.0)


## Returns the force direction scaled by the current strength (length between 0 and 1).
func get_force() -> Vector2:
	var viewport: Viewport = get_viewport()
	var offset: Vector2 = viewport.get_mouse_position() - viewport.get_visible_rect().size / 2.0
	if offset.length() <= dead_zone:
		return Vector2.ZERO
	return offset.normalized() * strength
