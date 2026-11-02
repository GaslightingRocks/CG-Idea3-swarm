class_name Flock
extends Node2D

## A swarm of boids. Spawns its boids around its own position and passes the player's force on to them.
## The boids are children of this node. A second swarm is simply a second Flock node with other settings.

## Emitted whenever the number of flying, saved or lost boids changes (e.g. to update the HUD).
signal counts_changed
## Emitted when a boid of this flock gets hit but survives (e.g. a hunter hit by the attack), used for camera shake.
signal boid_hit

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
# The swarm's courage supply, the currency for special abilities. It slowly fills up while enough of the
# boids fly in a group (settings.courage_min_group_share) and is emptied by using abilities.
var courage_pool: float = 0.0
# share of boids (0 to 1) that currently count as "in a group"
var group_share: float = 0.0

# State of the special abilities, started by PlayerAbilities and read by the boids
var dodge_time_left: float = 0.0
var dodge_speed_multiplier: float = 1.0
var attacking: bool = false
var attack_speed_multiplier: float = 1.0
var attack_steer_multiplier: float = 1.0
var attack_steer_weight: float = 0.0
var attack_range: float = 0.0
# flock whose boids are attacked, and the one of them the whole swarm currently charges at
var attack_victims: Flock = null
var attack_target: Boid = null
# after an attack the boids are pulled together much stronger for a moment, so the swarm reunites
var regroup_time_left: float = 0.0
var regroup_pull_multiplier: float = 1.0
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


func _physics_process(delta: float) -> void:
	# Godot processes a parent before its children, so this runs before the boids read the force
	player_force = player_influence.get_force() if player_influence else Vector2.ZERO
	update_center()
	fill_courage_pool(delta)
	dodge_time_left = maxf(dodge_time_left - delta, 0.0)
	regroup_time_left = maxf(regroup_time_left - delta, 0.0)
	if is_attacking():
		attack_target = find_attack_target()


## True while the dodge ability is active: the boids are faster and hunters can't catch them.
func is_dodging() -> bool:
	return dodge_time_left > 0.0


## True while the attack ability is active: the boids fly at hunters and hurt them on contact.
func is_attacking() -> bool:
	return attacking


## True for a short time after an attack, while the boids are pulled back together.
func is_regrouping() -> bool:
	return regroup_time_left > 0.0


## Starts the dodge: every boid turns in the player's direction (or the flock's flight direction)
## and flies faster for the given time.
func start_dodge(duration: float, speed_multiplier: float) -> void:
	dodge_time_left = duration
	dodge_speed_multiplier = speed_multiplier
	var direction: Vector2 = player_force if not player_force.is_zero_approx() else average_velocity
	if direction.is_zero_approx():
		return
	for boid: Boid in boids:
		boid.velocity = direction.normalized() * boid.settings.speed * speed_multiplier


## Starts the attack: the whole swarm lunges at the nearest boid of the victims flock (within range),
## flies faster and turns sharper until stop_attack() is called.
func start_attack(victims: Flock, range_px: float, speed_multiplier: float,
		steer_multiplier: float, steer_weight: float) -> void:
	attacking = true
	regroup_time_left = 0.0
	attack_victims = victims
	attack_range = range_px
	attack_speed_multiplier = speed_multiplier
	attack_steer_multiplier = steer_multiplier
	attack_steer_weight = steer_weight
	attack_target = find_attack_target()

	# Lunge: every boid turns toward the target at once (or the mouse direction if there's none)
	var lunge_point: Vector2 = attack_target.global_position if attack_target else center + player_force * 100.0
	for boid: Boid in boids:
		var direction: Vector2 = lunge_point - boid.global_position
		if not direction.is_zero_approx():
			boid.velocity = direction.normalized() * boid.settings.speed * speed_multiplier


## Ends the attack at once, the player has control again. For regroup_duration seconds the boids are pulled
## toward the swarm's center pull_multiplier times as strong as usual, so the scattered swarm reunites.
func stop_attack(regroup_duration: float, pull_multiplier: float) -> void:
	attacking = false
	attack_target = null
	regroup_time_left = regroup_duration
	regroup_pull_multiplier = pull_multiplier


## Returns the victim closest to the swarm's center within attack_range, or null.
func find_attack_target() -> Boid:
	if attack_victims == null:
		return null
	var nearest: Boid = null
	var nearest_distance: float = attack_range
	for victim: Boid in attack_victims.boids:
		var distance: float = center.distance_to(victim.global_position)
		if distance < nearest_distance:
			nearest = victim
			nearest_distance = distance
	return nearest


## Fills the courage pool, but only while at least courage_min_group_share of the boids fly in a group.
## The more boids are in a group, the faster it fills.
func fill_courage_pool(delta: float) -> void:
	if group_share >= settings.courage_min_group_share:
		courage_pool += settings.courage_fill_rate * group_share * delta
	courage_pool = minf(courage_pool, settings.courage_pool_max)


## Pays the given amount from the courage pool. Returns false (and pays nothing) if there isn't enough.
func spend_courage(amount: float) -> bool:
	if courage_pool < amount:
		return false
	courage_pool -= amount
	return true


## Number of own-flock neighbors a boid needs in sight to count as "in a group":
## courage_group_percent of all boids of the flock, but at least 1.
func group_size_needed() -> int:
	return maxi(1, ceili(settings.courage_group_percent * boids.size()))


## Calculates center of mass, average velocity and group share once, instead of every boid doing it on its own.
func update_center() -> void:
	if boids.is_empty():
		center = global_position
		average_velocity = Vector2.ZERO
		group_share = 0.0
		return
	var position_sum: Vector2 = Vector2.ZERO
	var velocity_sum: Vector2 = Vector2.ZERO
	var in_group_count: int = 0
	for boid: Boid in boids:
		position_sum += boid.global_position
		velocity_sum += boid.velocity
		if boid.in_group:
			in_group_count += 1
	# Strays are pulled toward their home spot (via flock_pull_weight) instead of their center of mass
	center = global_position if stray_group else position_sum / boids.size()
	average_velocity = velocity_sum / boids.size()
	group_share = float(in_group_count) / boids.size()


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
