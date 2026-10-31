@tool
class_name StartZone
extends Node2D

## Where the swarm spawns at the start of a round. Move the node to change the start, change radius for its size.
## "@tool" makes the script run in the editor too, so the circle is visible while building the level.

# radius (in pixels) of the circle the boids spawn in
@export var radius: float = 80.0:
	set(value):
		radius = value
		queue_redraw()
@export var color: Color = Color(0.3, 0.9, 0.4, 0.25):
	set(value):
		color = value
		queue_redraw()
# text shown in the circle, e.g. "GEGNER" for the zone the hunters start in
@export var label: String = "START":
	set(value):
		label = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.8), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-radius, 6), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 18, Color(color, 0.8))
