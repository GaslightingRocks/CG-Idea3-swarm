class_name Flock
extends Node2D

## A swarm of boids. Spawns its boids around its own position and passes the player's force on to them.
## The boids are children of this node. A second swarm is simply a second Flock node with other settings.

## Emitted whenever the number of flying, saved or lost boids changes (e.g. to update the HUD).
signal counts_changed

# scene every boid of this flock is made from (e.g. res://flock/hunter.tscn for an enemy flock)
@export_file("*.tscn") var boid_scene_path: String = "res://flock/boid.tscn"
# true: every boid gets a random color, false: all boids get boid_color
@export var random_colors: bool = true
@export var boid_color: Color = Color.WHITE
# number of boids spawned at the start
@export var boid_count: int = 100
# radius (in pixels) around this node in which the boids spawn
@export var spawn_radius: float = 80.0
# tuning values shared by all boids of this flock
@export var settings: BoidSettings
# turns the mouse into a force; leave empty for a flock the player can't control
@export var player_influence: PlayerInfluence
# flock this flock hunts (used by hunters to find the player's swarm), leave empty for none
@export var target_flock: Flock
# true for a group of strays: its boids circle around this node instead of the flock's center
# and join the player's swarm when it comes within settings.join_radius
@export var stray_group: bool = false

# force the player currently applies, read by every boid in its own physics step
var player_force: Vector2 = Vector2.ZERO
# center of mass of all boids, updated once per physics step (the flock's own position if it has no boids)
var center: Vector2 = Vector2.ZERO
# average velocity of all boids, used so boids hitting a wall all turn to the same side
var average_velocity: Vector2 = Vector2.ZERO
# sum of the courage of all boids, the currency for special abilities
var total_courage: float = 0.0
# all boids that currently belong to this flock and are still flying
var boids: Array[Boid] = []
# boids that reached the goal / were killed
var saved_count: int = 0
var lost_count: int = 0
# Loaded in _ready() from a path instead of with preload(): boid.gd refers to Flock, so preloading the boid
# scene here would make Godot load boid.tscn -> boid.gd -> flock.gd -> boid.tscn in a circle ("Parse Error: Busy").
var boid_scene: PackedScene


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()
	boid_scene = load(boid_scene_path)
	if boid_scene == null:
		push_error("Flock '%s': boid scene '%s' could not be loaded, no boids will spawn." % [name, boid_scene_path])
	center = global_position
	randomize()

	# Waits until the TileMapLayer has registered its collision shapes, so spawning can avoid the walls
	for i in 2:
		await get_tree().physics_frame
	set_boid_count(boid_count)


func _physics_process(_delta: float) -> void:
	# Godot processes a parent before its children, so this runs before the boids read the force
	player_force = player_influence.get_force() if player_influence else Vector2.ZERO
	update_center()


## Calculates center of mass, average velocity and total courage once, instead of every boid doing it on its own.
func update_center() -> void:
	if boids.is_empty():
		center = global_position
		average_velocity = Vector2.ZERO
		total_courage = 0.0
		return
	var position_sum: Vector2 = Vector2.ZERO
	var velocity_sum: Vector2 = Vector2.ZERO
	total_courage = 0.0
	for boid: Boid in boids:
		position_sum += boid.global_position
		velocity_sum += boid.velocity
		total_courage += boid.courage
	# Strays are pulled toward their home spot (via flock_pull_weight) instead of their center of mass
	center = global_position if stray_group else position_sum / boids.size()
	average_velocity = velocity_sum / boids.size()


## Spawns or removes boids until exactly the given number of boids exists.
func set_boid_count(value: int) -> void:
	boid_count = value
	while boids.size() < boid_count:
		# Stops instead of looping forever if a boid can't be created
		if not spawn_boid():
			break
	while boids.size() > boid_count:
		var boid: Boid = boids.pop_back()
		remove_child(boid)
		boid.queue_free()
	counts_changed.emit()


## Called by a boid that was killed.
func on_boid_lost(boid: Boid) -> void:
	boids.erase(boid)
	lost_count += 1
	counts_changed.emit()


## Called by a boid that reached the goal.
func on_boid_saved(boid: Boid) -> void:
	boids.erase(boid)
	saved_count += 1
	counts_changed.emit()


## Takes over a boid from another flock, e.g. a stray joining the player's swarm.
## The boid gets this flock's settings and color from now on.
func adopt(boid: Boid) -> void:
	var old_flock: Flock = boid.flock
	if old_flock == self:
		return
	if old_flock:
		old_flock.boids.erase(boid)
		old_flock.counts_changed.emit()

	boid.flock = self
	boid.settings = settings
	boids.append(boid)
	boid.modulate = Color(randf(), randf(), randf(), 1) if random_colors else boid_color
	# Moves the node below this flock in the scene tree. "call_deferred" waits until the end of the frame,
	# because changing the scene tree in the middle of the physics step is not allowed.
	boid.reparent.call_deferred(self)
	counts_changed.emit()


## Instantiates a single boid and places it at a random free spot around the flock.
func spawn_boid() -> bool:
	if boid_scene == null:
		return false
	var boid: Boid = boid_scene.instantiate() as Boid
	if boid == null:
		push_error("Flock '%s': '%s' has no Boid script on its root node (maybe a script error?)." % [name, boid_scene_path])
		return false
	boid.settings = settings
	boid.flock = self
	add_child(boid)
	boids.append(boid)

	# Assigns a random RGB color (alpha remains 1 for full visibility) or the flock's fixed color
	boid.modulate = Color(randf(), randf(), randf(), 1) if random_colors else boid_color
	boid.global_position = random_free_position()
	# Tells the physics interpolation that this was a teleport, not a movement to smooth out
	boid.reset_physics_interpolation()
	return true


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
