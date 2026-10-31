extends Node2D

const BOID_SCENE: PackedScene = preload("res://flock/boid.tscn")

# number of boids
@export var boid_count: int = 100
# margin (in pixels) from the screen border where boids are allowed to spawn
@export var margin: float = 100.0
# tuning values shared by all boids, editable at runtime through the settings panel
@export var boid_settings: BoidSettings
var screen_size: Vector2


func _ready() -> void:
	if boid_settings == null:
		boid_settings = BoidSettings.new()

	screen_size = get_viewport_rect().size
	randomize()

	# Waits until the TileMapLayer has registered its collision shapes, so spawning can avoid the walls
	for i in 2:
		await get_tree().physics_frame

	for i in boid_count:
		spawn_boid()

	var settings_panel: BoidSettingsPanel = BoidSettingsPanel.new()
	settings_panel.settings = boid_settings
	add_child(settings_panel)
	settings_panel.add_slider("Boid Count", 0, 500, 1, boid_count, func(value: float) -> void: set_boid_count(int(value)))


## Called by a timer node to replenish the population.
func _on_timer_timeout() -> void:
	# Counts current child nodes (boids) inside the "$BoidFolder"
	var current: int = $BoidFolder.get_child_count()
	# Checks if boids are missing
	if current < boid_count:
		print("too few fish :(")
		for i in (boid_count - current):
			spawn_boid()


## Spawns or removes boids until exactly the given number of boids exists.
func set_boid_count(value: int) -> void:
	boid_count = value
	var current: int = $BoidFolder.get_child_count()
	for i in range(current, boid_count):
		spawn_boid()
	for i in range(current - 1, boid_count - 1, -1):
		var boid: Node = $BoidFolder.get_child(i)
		$BoidFolder.remove_child(boid)
		boid.queue_free()


## Instantiates a single boid and places it randomly in the world.
func spawn_boid() -> void:
	var boid: Boid = BOID_SCENE.instantiate() as Boid
	boid.settings = boid_settings

	# Adds the new boid as a child node to the designated folder
	$BoidFolder.add_child(boid)

	# Assigns a random RGB color to the boid (alpha remains 1 for full visibility)
	boid.modulate = Color(randf(), randf(), randf(), 1)

	boid.global_position = random_free_position()


## Returns a random position within the screen boundaries minus the margin that is not inside a wall.
func random_free_position() -> Vector2:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	for attempt in 50:
		query.position = Vector2(
			randf_range(margin, screen_size.x - margin),
			randf_range(margin, screen_size.y - margin)
		)
		if get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
			break
	return query.position
