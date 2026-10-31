class_name Flock
extends Node2D

## A swarm of boids. Spawns its boids around its own position and passes the player's force on to them.
## The boids are children of this node. A second swarm is simply a second Flock node with other settings.

const BOID_SCENE: PackedScene = preload("res://flock/boid.tscn")

# number of boids spawned at the start
@export var boid_count: int = 100
# radius (in pixels) around this node in which the boids spawn
@export var spawn_radius: float = 80.0
# tuning values shared by all boids of this flock
@export var settings: BoidSettings
# turns the mouse into a force; leave empty for a flock the player can't control
@export var player_influence: PlayerInfluence

# force the player currently applies, read by every boid in its own physics step
var player_force: Vector2 = Vector2.ZERO
# all boids that currently belong to this flock
var boids: Array[Boid] = []


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()
	randomize()

	# Waits until the TileMapLayer has registered its collision shapes, so spawning can avoid the walls
	for i in 2:
		await get_tree().physics_frame
	set_boid_count(boid_count)


func _physics_process(_delta: float) -> void:
	# Godot processes a parent before its children, so this runs before the boids read the force
	player_force = player_influence.get_force() if player_influence else Vector2.ZERO


## Returns the center of mass of all boids, or the flock's own position if it has none.
func get_center() -> Vector2:
	if boids.is_empty():
		return global_position
	var center: Vector2 = Vector2.ZERO
	for boid: Boid in boids:
		center += boid.global_position
	return center / boids.size()


## Spawns or removes boids until exactly the given number of boids exists.
func set_boid_count(value: int) -> void:
	boid_count = value
	while boids.size() < boid_count:
		spawn_boid()
	while boids.size() > boid_count:
		var boid: Boid = boids.pop_back()
		remove_child(boid)
		boid.queue_free()


## Instantiates a single boid and places it at a random free spot around the flock.
func spawn_boid() -> void:
	var boid: Boid = BOID_SCENE.instantiate() as Boid
	boid.settings = settings
	boid.flock = self
	add_child(boid)
	boids.append(boid)

	# Assigns a random RGB color to the boid (alpha remains 1 for full visibility)
	boid.modulate = Color(randf(), randf(), randf(), 1)
	boid.global_position = random_free_position()


## Returns a random position within spawn_radius around the flock that is not inside a wall.
func random_free_position() -> Vector2:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	for attempt in 50:
		# sqrt() spreads the points evenly over the circle instead of crowding them in the middle
		var offset: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * spawn_radius
		query.position = global_position + offset
		if get_world_2d().direct_space_state.intersect_point(query, 1).is_empty():
			break
	return query.position
