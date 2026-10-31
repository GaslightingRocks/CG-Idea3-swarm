extends Node2D

## Root of the game: holds the level, the flock, the camera and the UI.
## The flock spawns and steers the boids, this script only sets up the UI around it.

@onready var flock: Flock = $Flock


func _ready() -> void:
	# Child nodes are ready before their parent, so the flock already has its settings here
	var settings_panel: BoidSettingsPanel = BoidSettingsPanel.new()
	settings_panel.settings = flock.settings
	add_child(settings_panel)
	settings_panel.add_slider("Boid Count", 0, 500, 1, flock.boid_count, func(value: float) -> void: flock.set_boid_count(int(value)))
