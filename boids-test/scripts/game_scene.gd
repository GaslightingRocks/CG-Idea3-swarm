extends Node2D

# number of boids
@export var num := 100
# margin (in pixels) from the screen border where boids are allowed to spawn
@export var margin := 100
var screensize : Vector2

func _ready() -> void:
	screensize = get_viewport_rect().size
	randomize()
	for i in num:
		spawnBoid()

## Called by a timer node to replenish the population.
func _on_Timer_timeout() -> void:
	# Counts current child nodes (boids) inside the "$boidFolder" 
	var c := $boidFolder.get_child_count() 
	# Checks if boids are missing
	if c < num:
		print("too few fish :(")
		for i in (num - c):
			spawnBoid()


## Instantiates a single boid and places it randomly in the world.
func spawnBoid() -> void:
	# Loads the boid scene and creates a new instance of it
	var boid : Area2D = preload("res://scenes/boid.tscn").instantiate()
	
	# Adds the new boid as a child node to the designated folder
	$boidFolder.add_child(boid)
	
	# Assigns a random RGB color to the boid (alpha remains 1 for full visibility)
	boid.modulate = Color(randf(), randf(), randf(), 1)
	
	# Calculates a random X and Y position within the screen boundaries minus the margin
	var random_x := randf_range(margin, screensize.x - margin)
	var random_y := randf_range(margin, screensize.y - margin)
	boid.global_position = Vector2(random_x, random_y)
