class_name DebugOverlay
extends Node2D

## Debug view, switched on and off with the "toggle_debug" input action (F3).
## Draws every boid's vision circle and steering forces into the world, shows FPS, physics time
## and boid counts in the top left corner, and zooms the camera out so the whole level is visible.

# how many pixels a force of 1 is drawn long
const FORCE_SCALE: float = 3.0
# how many pixels a velocity of 1 (pixel per physics step) is drawn long
const VELOCITY_SCALE: float = 4.0
const VELOCITY_COLOR: Color = Color(0.3, 1.0, 0.3)
const FLOCKING_COLOR: Color = Color(0.3, 0.8, 1.0)
const PLAYER_COLOR: Color = Color(1.0, 1.0, 1.0)
const WALL_COLOR: Color = Color(1.0, 0.6, 0.1)
const BEHAVIOR_COLOR: Color = Color(1.0, 0.3, 0.8)

# Whether the overlay is on. "static" means the variable belongs to the script instead of a single node,
# so it survives restarting the round (R reloads the scene and creates a new overlay node).
static var enabled: bool = false

# flocks whose boids are drawn, set by the game
var flocks: Array[Flock] = []
# camera that is zoomed out while the overlay is on
var camera: Camera2D
# camera zoom while the overlay is on (smaller = further out)
var debug_zoom: Vector2 = Vector2(0.6, 0.6)
var normal_zoom: Vector2
var info_label: Label


func _ready() -> void:
	# Drawn on top of everything else in the world
	z_index = 100

	# Text in screen space, so it doesn't move with the camera
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 4)
	info_label.visible = false
	layer.add_child(info_label)
	# Bottom left corner with 16 px margin, growing upward (the settings panels are in the top left)
	info_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)

	if camera:
		normal_zoom = camera.zoom
	# Turns the overlay back on if it was on before the restart
	set_enabled(enabled)


func _unhandled_input(event: InputEvent) -> void:
	# "toggle_debug" is defined in Project Settings > Input Map (F3 by default)
	if event.is_action_pressed("toggle_debug"):
		set_enabled(not enabled)


## Shows or hides the overlay and zooms the camera out or back in.
func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	info_label.visible = value
	if camera:
		camera.zoom = debug_zoom if value else normal_zoom


func _process(_delta: float) -> void:
	if not visible:
		return
	# Asks Godot to call _draw() again, since everything moves every frame
	queue_redraw()
	update_info()


func _draw() -> void:
	for flock: Flock in flocks:
		for boid: Boid in flock.boids:
			if not is_instance_valid(boid):
				continue
			var at: Vector2 = boid.global_position
			draw_arc(at, boid.settings.vision_radius, 0.0, TAU, 24, Color(1, 1, 1, 0.08), 1.0)
			draw_line(at, at + boid.velocity * VELOCITY_SCALE, VELOCITY_COLOR, 1.0)
			draw_force(at, boid.debug_flocking_force, FLOCKING_COLOR)
			draw_force(at, boid.debug_player_force, PLAYER_COLOR)
			draw_force(at, boid.debug_wall_force, WALL_COLOR)
			draw_force(at, boid.debug_behavior_force, BEHAVIOR_COLOR)

		# Center of mass of the flock as a small cross
		var size: float = 12.0
		draw_line(flock.center - Vector2(size, 0), flock.center + Vector2(size, 0), Color.YELLOW, 2.0)
		draw_line(flock.center - Vector2(0, size), flock.center + Vector2(0, size), Color.YELLOW, 2.0)


## Draws one steering force as a line starting at the boid, skips forces that are (almost) zero.
func draw_force(at: Vector2, force: Vector2, color: Color) -> void:
	if force.length_squared() > 0.0001:
		draw_line(at, at + force * FORCE_SCALE, color, 1.0)


## Updates the text with performance numbers, boid counts and the color legend.
func update_info() -> void:
	var text: String = "DEBUG (F3)\n"
	text += "FPS: %d\n" % Engine.get_frames_per_second()
	text += "Physics: %.1f ms   Process: %.1f ms\n" % [
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
	]
	for flock: Flock in flocks:
		text += "%s: %d flying, %d saved, %d lost\n" % [flock.name, flock.boids.size(), flock.saved_count, flock.lost_count]
	text += "\ngreen: velocity   blue: flocking   white: player\norange: walls   pink: flee / chase   yellow: flock center"
	info_label.text = text
