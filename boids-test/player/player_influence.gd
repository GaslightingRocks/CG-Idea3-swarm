class_name PlayerInfluence
extends Node

## Turns the mouse into a steering force for a flock.
## The vector from the screen center to the mouse gives the direction,
## its length gives the strength: 0 inside the dead zone, 1 at max_mouse_distance and beyond.
## Since the camera follows the swarm, the screen center is roughly where the swarm is.

# mouse distance (in screen pixels) from the screen center at which the force reaches full strength
@export var max_mouse_distance: float = 400.0
# mouse distance (in screen pixels) below which there's no force, so the swarm can fly on its own
@export var dead_zone: float = 30.0


## Returns the force direction scaled by its strength (length between 0 and 1).
func get_force() -> Vector2:
	var viewport: Viewport = get_viewport()
	var offset: Vector2 = viewport.get_mouse_position() - viewport.get_visible_rect().size / 2.0
	var distance: float = offset.length()
	if distance <= dead_zone:
		return Vector2.ZERO
	var strength: float = clampf((distance - dead_zone) / (max_mouse_distance - dead_zone), 0.0, 1.0)
	return offset / distance * strength
