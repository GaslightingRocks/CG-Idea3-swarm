class_name InfluenceIndicator
extends Control

## Draws the player's force in the middle of the screen: a faint ring for full strength,
## a second ring for the current strength (mouse wheel) and an arrow in the current direction.
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

	# Full-strength ring, current-strength ring and the strength in percent below
	var strength: float = player_influence.strength
	draw_arc(center, indicator_radius, 0.0, TAU, 64, faint, 2.0, true)
	if strength > 0.0:
		draw_arc(center, indicator_radius * strength, 0.0, TAU, 64, Color(color, color.a * 0.5), 2.0, true)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, center + Vector2(-60, indicator_radius + 28), "Kraft %d%%" % roundi(strength * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(color, color.a * 0.75))

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
