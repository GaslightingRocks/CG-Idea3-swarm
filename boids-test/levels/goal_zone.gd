@tool
class_name GoalZone
extends Area2D

## The goal of a level: every boid that flies into this circle is saved.
## Move the node to change the goal, change radius for its size. The collision circle is created from radius.
## "@tool" makes the script run in the editor too, so the circle is visible while building the level.

# radius (in pixels) of the goal circle
@export var radius: float = 90.0:
	set(value):
		radius = value
		queue_redraw()
@export var color: Color = Color(1.0, 0.8, 0.2, 0.25)


func _ready() -> void:
	# The collision is only needed in the running game, not in the editor
	if Engine.is_editor_hint():
		return

	# Detects boids (layer 2 "Boids"), sits on layer 3 "Zones" itself
	collision_layer = 4
	collision_mask = 2
	monitorable = false

	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	var shape: CollisionShape2D = CollisionShape2D.new()
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.8), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(-radius, 6), "ZIEL", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 18, Color(color, 0.8))


## Saves every boid that enters the goal.
func _on_area_entered(area: Area2D) -> void:
	if area is Boid:
		(area as Boid).save()
