class_name Boid
extends Area2D

# distance the boid keeps from a wall it slides along
const WALL_SKIN: float = 2.0
# number of wall detection rays, spread evenly from left to right
const WALL_RAY_COUNT: int = 7
# length of the outermost side rays relative to the forward ray
const SIDE_RAY_LENGTH_FACTOR: float = 0.6
# radius (in pixels) of the circle the boid's body occupies, two boids are never closer than twice this
const BODY_RADIUS: float = 8.0
# distance (in pixels) from the boid's center to its tip, a wall closer than this in flight direction kills it
const NOSE_LENGTH: float = 6.0

# FLYING: on its way, SAVED: reached the goal, LOST: hit a wall
enum State { FLYING, SAVED, LOST }

# physics layers the boid can't fly through (the level TileMapLayer is on layer 1 "Walls")
@export_flags_2d_physics var wall_collision_mask: int = 1

## Shared tuning values, assigned by the spawner. Falls back to the defaults when the scene runs on its own.
var settings: BoidSettings
## The swarm this boid belongs to. null means it's a stray that doesn't react to the player.
var flock: Flock

# circle shape of the "Vision" area, its radius follows settings.vision_radius
@onready var vision_shape: CircleShape2D = $Vision/CollisionShape2D.shape
# wall detection rays, created in code so their length and angle can be tuned in the settings
var rays: Array[RayCast2D] = []
# ray settings the rays were last built with, to notice slider changes
var ray_look_ahead: float = 0.0
var ray_spread: float = 0.0
var visible_boids: Array[Boid] = []
# current velocity vector of boid
var velocity: Vector2 = Vector2.ZERO
var state: State = State.FLYING


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()

	create_rays()
	randomize()

	# Assigns a random initial flight direction and normalizes it to match speed
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * settings.speed


func _physics_process(_delta: float) -> void:
	apply_setting_changes()

	# The wall push is needed twice: to avoid the wall and to turn the player force along it
	var wall_push: Vector2 = wall_force()
	var steering: Vector2 = flocking_force() + flock_pull_force() + player_force(wall_push)
	steering += wall_push * settings.wall_avoidance_weight

	# Limits how much the velocity can change per frame, which smooths out sudden turns
	velocity += steering.limit_length(settings.max_steer_force)
	if velocity.is_zero_approx():
		velocity = Vector2.RIGHT.rotated(rotation)

	# Enforces constant speed
	velocity = velocity.normalized() * settings.speed

	# Touching a wall costs the boid (can be switched off with lethal_walls in the settings)
	if settings.lethal_walls and hits_wall_ahead():
		die()
		return

	move()
	resolve_overlaps()

	# Smoothly interpolates the rotation angle toward the current velocity vector
	rotation = lerp_angle(rotation, velocity.angle(), settings.rotation_smoothing)


## Creates the wall detection rays as children, so they turn together with the boid.
func create_rays() -> void:
	for i in WALL_RAY_COUNT:
		var ray: RayCast2D = RayCast2D.new()
		ray.collision_mask = wall_collision_mask
		add_child(ray)
		rays.append(ray)
	update_rays()


## Applies slider changes from the settings panel.
## Only touches the physics shapes when a value really changed: resizing the vision circle
## makes the physics engine recheck all overlaps, doing that every frame for every boid causes heavy stutters.
func apply_setting_changes() -> void:
	if vision_shape.radius != settings.vision_radius:
		vision_shape.radius = settings.vision_radius
	if ray_look_ahead != settings.wall_look_ahead or ray_spread != settings.wall_ray_spread:
		update_rays()


## Points the rays fan-shaped to the front: the middle ray is the longest, the outer ones are shorter.
func update_rays() -> void:
	ray_look_ahead = settings.wall_look_ahead
	ray_spread = settings.wall_ray_spread
	for i in rays.size():
		# -1 for the leftmost ray, 0 for the middle one, +1 for the rightmost ray
		var side: float = lerpf(-1.0, 1.0, float(i) / (rays.size() - 1))
		var angle: float = deg_to_rad(settings.wall_ray_spread) * side
		var length: float = settings.wall_look_ahead * lerpf(1.0, SIDE_RAY_LENGTH_FACTOR, absf(side))
		rays[i].target_position = Vector2.RIGHT.rotated(angle) * length


## Returns the steering force needed to turn the current velocity toward the given direction.
func steer_towards(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return direction.normalized() * settings.speed - velocity


## Calculates flocking forces (alignment, cohesion, and separation) based on visible neighbors.
func flocking_force() -> Vector2:
	remove_freed_boids()
	if visible_boids.is_empty():
		return Vector2.ZERO

	var avg_velocity: Vector2 = Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	var separation: Vector2 = Vector2.ZERO
	for boid: Boid in visible_boids:
		avg_velocity += boid.velocity
		center += boid.global_position
		var offset: Vector2 = global_position - boid.global_position
		var distance: float = offset.length()
		# Only neighbors inside the personal space push away, closer ones much stronger
		if distance > 0.0 and distance < settings.separation_radius:
			separation += offset / (distance * distance)
	center /= visible_boids.size()

	# Alignment: Match flight direction with neighbors
	var force: Vector2 = steer_towards(avg_velocity) * settings.alignment_weight
	# Cohesion: Move toward the center of mass of neighbors
	force += steer_towards(center - global_position) * settings.cohesion_weight
	# Separation: Steer away to avoid crowding neighbors
	force += steer_towards(separation) * settings.separation_weight
	return force


## Uses raycasts to detect walls in the "blocks" group and pushes the boid away along the wall normal.
func wall_force() -> Vector2:
	var force: Vector2 = Vector2.ZERO
	for ray: RayCast2D in rays:
		if ray.is_colliding() and ray.get_collider().is_in_group("blocks"):
			var ray_length: float = ray.target_position.length()
			var distance: float = (ray.get_collision_point() - ray.global_position).length()
			# Grows linearly from 0 at the end of the ray to 1 directly at the wall
			var proximity: float = 1.0 - clampf(distance / ray_length, 0.0, 1.0)
			force += ray.get_collision_normal() * proximity
	return force * settings.speed


## Gently pulls the boid toward the center of its whole flock, so separated groups find back together.
func flock_pull_force() -> Vector2:
	if flock == null:
		return Vector2.ZERO
	return steer_towards(flock.center - global_position) * settings.flock_pull_weight


## Steers toward where the player points the mouse, stronger the further the mouse is from the screen center.
## Near a wall the force is turned along the wall instead of pushing the boid into it.
func player_force(wall_push: Vector2) -> Vector2:
	if flock == null:
		return Vector2.ZERO
	var force: Vector2 = flock.player_force
	if force.is_zero_approx():
		return Vector2.ZERO
	if not wall_push.is_zero_approx():
		var normal: Vector2 = wall_push.normalized()
		if force.dot(normal) < 0.0:
			force = along_wall(force, normal)
	return steer_towards(force) * force.length() * settings.player_influence_weight


## Turns a direction that points into a wall so it runs along the wall instead, keeping its length.
## If it points almost straight into the wall, the boid turns to the side the whole flock is flying to.
## That way all boids of a swarm slide the same way and the swarm doesn't split up at the wall.
func along_wall(direction: Vector2, normal: Vector2) -> Vector2:
	var tangent: Vector2 = normal.orthogonal()
	var reference: Vector2 = direction.slide(normal)
	if reference.length() < direction.length() * 0.3 and flock != null:
		reference = flock.average_velocity
	var side: float = 1.0 if reference.dot(tangent) >= 0.0 else -1.0
	return tangent * side * direction.length()


## Drops neighbors that were deleted (e.g. when the boid count is lowered) without leaving the vision area.
func remove_freed_boids() -> void:
	for i in range(visible_boids.size() - 1, -1, -1):
		if not is_instance_valid(visible_boids[i]):
			visible_boids.remove_at(i)


## Returns true if the boid's tip would touch a wall during this step's movement.
func hits_wall_ahead() -> bool:
	var tip: Vector2 = global_position + velocity + velocity.normalized() * NOSE_LENGTH
	return not cast_wall_ray(global_position, tip).is_empty()


## Called when the boid hits a wall: it leaves its flock and disappears.
func die() -> void:
	if state != State.FLYING:
		return
	state = State.LOST
	if flock:
		flock.on_boid_lost(self)
	queue_free()


## Called by the goal zone: the boid is saved, leaves its flock and disappears.
func save() -> void:
	if state != State.FLYING:
		return
	state = State.SAVED
	if flock:
		flock.on_boid_saved(self)
	queue_free()


## Moves the boid and slides along walls instead of passing through them.
func move() -> void:
	global_position += clip_against_walls(velocity, true)


## Pushes the boid out of every neighbor it overlaps with, so two boids never share the same space.
## Each of the two boids moves half of the overlap, together they end up exactly touching.
func resolve_overlaps() -> void:
	var push: Vector2 = Vector2.ZERO
	var min_distance: float = BODY_RADIUS * 2.0
	for boid: Boid in visible_boids:
		var offset: Vector2 = global_position - boid.global_position
		var distance: float = offset.length()
		if distance >= min_distance:
			continue
		# Boids exactly on top of each other have no direction to push in, so a random one is used
		var direction: Vector2 = offset / distance if distance > 0.0 else Vector2.RIGHT.rotated(randf() * TAU)
		push += direction * (min_distance - distance) * 0.5

	if not push.is_zero_approx():
		global_position += clip_against_walls(push, false)


## Returns the part of the motion that doesn't run into a wall.
## When turn_velocity is true, the velocity is turned along the wall as well.
func clip_against_walls(motion: Vector2, turn_velocity: bool) -> Vector2:
	# A few iterations so the boid also handles corners where it touches two walls at once
	for i in 3:
		if motion.is_zero_approx():
			break
		var hit: Dictionary = cast_wall_ray(global_position, global_position + motion + motion.normalized() * WALL_SKIN)
		if hit.is_empty():
			break
		var normal: Vector2 = hit["normal"]
		# Removes the part of the motion that points into the wall
		motion = motion.slide(normal)
		if turn_velocity:
			var old_velocity: Vector2 = velocity
			velocity = velocity.slide(normal)
			# Flying (almost) straight into the wall leaves little to slide with,
			# so the boid turns along the wall to the side its flock is heading
			if velocity.length() < settings.speed * 0.3:
				velocity = along_wall(old_velocity, normal).normalized() * settings.speed
	return motion


## Casts a ray against the level geometry and returns the hit, or an empty dictionary if nothing was hit.
func cast_wall_ray(from: Vector2, to: Vector2) -> Dictionary:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, wall_collision_mask)
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit["collider"] as Node).is_in_group("blocks"):
		return {}
	return hit


## Adds a neighboring boid to the tracking array when it enters the vision area.
func _on_vision_area_entered(area: Area2D) -> void:
	if area != self and area is Boid:
		visible_boids.append(area)


## Removes a boid from the tracking array when it leaves the vision area.
func _on_vision_area_exited(area: Area2D) -> void:
	if area is Boid:
		visible_boids.erase(area)
