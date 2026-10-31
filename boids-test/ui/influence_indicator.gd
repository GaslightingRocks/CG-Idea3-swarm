class_name InfluenceIndicator
extends Control

## Draws the player's force in the middle of the screen: a faint ring for full strength,
## a small ring for the dead zone and an arrow whose direction and length show the current force.
## Covers the whole screen but ignores the mouse, so it never blocks clicks.

# where the force comes from
@export var player_influence: PlayerInfluence
# radius (in screen pixels) of the full-strength ring, the arrow reaches it at strength 1
@export var indicator_radius: float = 90.0
@export var color: Color = Color(1, 1, 1, 0.8)


func _process(_delta: float) -> void:
	# Asks Godot to call _draw() again, since the force changes every frame
	queue_redraw()


func _draw() -> void:
	if player_influence == null:
		return
	var center: Vector2 = size / 2.0
	var faint: Color = Color(color, color.a * 0.25)

	# Full-strength ring and dead zone, scaled to the indicator size
	draw_arc(center, indicator_radius, 0.0, TAU, 64, faint, 2.0, true)
	var dead_zone_radius: float = indicator_radius * player_influence.dead_zone / player_influence.max_mouse_distance
	draw_arc(center, dead_zone_radius, 0.0, TAU, 32, faint, 2.0, true)

	var force: Vector2 = player_influence.get_force()
	if force.is_zero_approx():
		return

	# Arrow from the center, its length shows the strength
	var tip: Vector2 = center + force * indicator_radius
	var direction: Vector2 = force.normalized()
	draw_line(center, tip, color, 3.0, true)
	var head_size: float = 12.0
	draw_line(tip, tip - direction.rotated(0.5) * head_size, color, 3.0, true)
	draw_line(tip, tip - direction.rotated(-0.5) * head_size, color, 3.0, true)
