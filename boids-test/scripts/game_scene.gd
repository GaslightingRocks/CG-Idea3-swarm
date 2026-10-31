extends Node2D

const BOID_SCENE: PackedScene = preload("res://scenes/boid.tscn")

# number of boids
@export var boid_count: int = 100
# margin (in pixels) from the screen border where boids are allowed to spawn
@export var margin: float = 100.0
var screen_size: Vector2


func _ready() -> void:
	screen_size = get_viewport_rect().size
	randomize()
	for i in boid_count:
		spawn_boid()


## Called by a timer node to replenish the population.
func _on_timer_timeout() -> void:
	# Counts current child nodes (boids) inside the "$BoidFolder"
	var current: int = $BoidFolder.get_child_count()
	# Checks if boids are missing
	if current < boid_count:
		print("too few fish :(")
		for i in (boid_count - current):
			spawn_boid()


## Instantiates a single boid and places it randomly in the world.
func spawn_boid() -> void:
	var boid: Boid = BOID_SCENE.instantiate() as Boid

	# Adds the new boid as a child node to the designated folder
	$BoidFolder.add_child(boid)

	# Assigns a random RGB color to the boid (alpha remains 1 for full visibility)
	boid.modulate = Color(randf(), randf(), randf(), 1)

	# Calculates a random X and Y position within the screen boundaries minus the margin
	var random_x: float = randf_range(margin, screen_size.x - margin)
	var random_y: float = randf_range(margin, screen_size.y - margin)
	boid.global_position = Vector2(random_x, random_y)
