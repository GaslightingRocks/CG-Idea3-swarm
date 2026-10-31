extends Node2D

## Root of the game: holds the level, the flocks, the camera and the UI.
## Places the flocks in the level's zones, keeps the HUD up to date and restarts the round.

@onready var level: Level = $Level
@onready var flock: Flock = $Flock
@onready var enemy_flock: Flock = $EnemyFlock
@onready var camera: SwarmCamera = $Camera2D
@onready var hud: Hud = $UI/Hud
# one flock per StrayZone of the level, created in _ready()
var stray_flocks: Array[Flock] = []


func _ready() -> void:
	# The flocks wait two physics frames before spawning, so they can still be moved to their zones here
	place_flock(flock, level.start_zone)
	if level.enemy_zone:
		place_flock(enemy_flock, level.enemy_zone)
	else:
		enemy_flock.boid_count = 0

	spawn_stray_flocks()

	camera.global_position = flock.global_position
	# Tells the physics interpolation that the camera jumped there, instead of smoothly flying there
	camera.reset_physics_interpolation()

	flock.counts_changed.connect(update_hud)
	enemy_flock.counts_changed.connect(update_hud)
	for strays: Flock in stray_flocks:
		strays.counts_changed.connect(update_hud)
	update_hud()

	# Child nodes are ready before their parent, so the flocks already have their settings here
	var settings_panel: BoidSettingsPanel = add_settings_panel(flock, "Boid Settings", Vector2(8, 8))
	settings_panel.add_slider("Boid Count", 0, 500, 1, flock.boid_count, func(value: float) -> void: flock.set_boid_count(int(value)))
	var enemy_panel: BoidSettingsPanel = add_settings_panel(enemy_flock, "Hunter Settings", Vector2(470, 8))
	enemy_panel.add_slider("Hunter Count", 0, 100, 1, enemy_flock.boid_count, func(value: float) -> void: enemy_flock.set_boid_count(int(value)))

	var debug_overlay: DebugOverlay = DebugOverlay.new()
	debug_overlay.flocks.append(flock)
	debug_overlay.flocks.append(enemy_flock)
	debug_overlay.flocks.append_array(stray_flocks)
	debug_overlay.camera = camera
	add_child(debug_overlay)


func _process(_delta: float) -> void:
	# Courage changes all the time, so it's updated every frame instead of only on count changes
	hud.show_courage(flock.total_courage, flock.boids.size())


func _unhandled_input(event: InputEvent) -> void:
	# "restart" is defined in Project Settings > Input Map (R by default)
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


## Moves a flock into a zone of the level, so its boids spawn there.
func place_flock(target: Flock, zone: StartZone) -> void:
	target.global_position = zone.global_position
	target.spawn_radius = zone.radius
	target.center = target.global_position


## Creates a group of strays for every StrayZone in the level. Strays fly slower, circle around their zone
## and get the player's settings and colors once they join the swarm.
func spawn_stray_flocks() -> void:
	var stray_settings: BoidSettings = flock.settings.duplicate()
	stray_settings.speed = 3.0
	stray_settings.flock_pull_weight = 1.0
	for zone: StrayZone in level.get_stray_zones():
		var strays: Flock = Flock.new()
		strays.name = "Strays_" + zone.name
		strays.stray_group = true
		strays.random_colors = false
		strays.boid_color = Color(0.6, 0.65, 0.75)
		strays.boid_count = zone.boid_count
		strays.settings = stray_settings
		add_child(strays)
		place_flock(strays, zone)
		stray_flocks.append(strays)


## Creates a slider panel for the settings of a flock.
func add_settings_panel(target: Flock, title: String, panel_position: Vector2) -> BoidSettingsPanel:
	var panel: BoidSettingsPanel = BoidSettingsPanel.new()
	panel.settings = target.settings
	panel.title_text = title
	panel.panel_position = panel_position
	add_child(panel)
	return panel


## Updates the counters and shows the result once none of the player's boids is flying anymore.
func update_hud() -> void:
	var saved: int = flock.saved_count
	var lost: int = flock.lost_count
	var strays_left: int = 0
	for strays: Flock in stray_flocks:
		strays_left += strays.boids.size()
	hud.show_counts(flock.boids.size(), saved, lost, enemy_flock.boids.size(), strays_left)

	if flock.boids.is_empty() and saved + lost > 0:
		hud.show_message("Runde vorbei: %d von %d gerettet\nR: Neustart" % [saved, saved + lost])
	else:
		hud.show_message("")
