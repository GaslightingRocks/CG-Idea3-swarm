extends Node2D

## Root of the game: holds the level, the flock, the camera and the UI.
## Places the flock in the level's start zone, keeps the HUD up to date and restarts the round.

@onready var level: Level = $Level
@onready var flock: Flock = $Flock
@onready var camera: SwarmCamera = $Camera2D
@onready var hud: Hud = $UI/Hud


func _ready() -> void:
	# The flock waits two physics frames before spawning, so it can still be moved to the start zone here
	flock.global_position = level.start_zone.global_position
	flock.spawn_radius = level.start_zone.radius
	flock.center = flock.global_position
	camera.global_position = flock.global_position
	# Tells the physics interpolation that the camera jumped there, instead of smoothly flying there
	camera.reset_physics_interpolation()

	flock.counts_changed.connect(update_hud)
	update_hud()

	# Child nodes are ready before their parent, so the flock already has its settings here
	var settings_panel: BoidSettingsPanel = BoidSettingsPanel.new()
	settings_panel.settings = flock.settings
	add_child(settings_panel)
	settings_panel.add_slider("Boid Count", 0, 500, 1, flock.boid_count, func(value: float) -> void: flock.set_boid_count(int(value)))


func _unhandled_input(event: InputEvent) -> void:
	# "restart" is defined in Project Settings > Input Map (R by default)
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


## Updates the counters and shows the result once no boid is flying anymore.
func update_hud() -> void:
	var saved: int = flock.saved_count
	var lost: int = flock.lost_count
	hud.show_counts(flock.boids.size(), saved, lost)

	if flock.boids.is_empty() and saved + lost > 0:
		hud.show_message("Runde vorbei: %d von %d gerettet\nR: Neustart" % [saved, saved + lost])
	else:
		hud.show_message("")
