class_name Boid
extends Area2D

# distance the boid keeps from a wall it slides along
const WALL_SKIN: float = 2.0
# number of wall detection rays, spread evenly from left to right
const WALL_RAY_COUNT: int = 7
# length of the outermost side rays relative to the forward ray
const SIDE_RAY_LENGTH_FACTOR: float = 0.6
# the wall rays are only cast every this many physics steps, which saves a lot of performance
const WALL_CHECK_INTERVAL: int = 2
# radius (in pixels) of the circle the boid's body occupies, two boids of a flock are never closer than twice this
const BODY_RADIUS: float = 5.0
# distance (in pixels) from the boid's center to its tip, a wall closer than this in flight direction kills it
const NOSE_LENGTH: float = 6.0

# FLYING: on its way, SAVED: reached the goal, LOST: was killed
enum State { FLYING, SAVED, LOST }

# physics layers the boid can't fly through (layer 1 "Walls")
@export_flags_2d_physics var wall_collision_mask: int = 1

## Shared tuning values, assigned by the spawner. Falls back to the defaults when the scene runs on its own.
var settings: BoidSettings
## The swarm this boid belongs to. null means it's a stray that doesn't react to the player.
var flock: Flock

# circle shape of the "Vision" area, its radius follows settings.vision_radius
@onready var vision_shape: CircleShape2D = $Vision/CollisionShape2D.shape
# all boids (of any flock) inside the vision circle, kept up to date by the Vision area's signals
var visible_boids: Array[Boid] = []
# current velocity vector of boid
var velocity: Vector2 = Vector2.ZERO
var state: State = State.FLYING

# push away from walls, sum of the wall normals the rays hit (recalculated every WALL_CHECK_INTERVAL steps)
var wall_push: Vector2 = Vector2.ZERO
# spreads the wall checks of all boids evenly over the physics steps
var wall_check_offset: int = 0

# Results of scan_neighbors(), recalculated every physics step in a single pass over visible_boids.
# Doing everything in one loop instead of one loop per rule is the main performance trick here.
var neighbor_count: int = 0
var neighbor_velocity_sum: Vector2 = Vector2.ZERO
var neighbor_position_sum: Vector2 = Vector2.ZERO
var separation_push: Vector2 = Vector2.ZERO
var overlap_push: Vector2 = Vector2.ZERO
var hunter_threat: Vector2 = Vector2.ZERO


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()
	randomize()
	wall_check_offset = randi() % WALL_CHECK_INTERVAL

	# Assigns a random initial flight direction and normalizes it to match speed
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * settings.speed


func _physics_process(_delta: float) -> void:
	apply_setting_changes()
	scan_neighbors()
	update_wall_push()

	var steering: Vector2 = flocking_force() + flock_pull_force() + player_force()
	steering += wall_push * settings.wall_avoidance_weight
	steering += behavior_force()

	# Limits how much the velocity can change per frame, which smooths out sudden turns
	velocity += steering.limit_length(settings.max_steer_force)
	if velocity.is_zero_approx():
		velocity = Vector2.RIGHT.rotated(rotation)

	# Enforces constant speed
	velocity = velocity.normalized() * settings.speed

	# Touching a wall costs the boid if lethal_walls is switched on in the settings
	if settings.lethal_walls and hits_wall_ahead():
		die()
		return

	move()
	resolve_overlaps()

	# Smoothly interpolates the rotation angle toward the current velocity vector
	rotation = lerp_angle(rotation, velocity.angle(), settings.rotation_smoothing)


## Applies slider changes from the settings panel.
## Only touches the vision shape when the value really changed: resizing it makes the physics engine
## recheck all overlaps, doing that every frame for every boid causes heavy stutters.
func apply_setting_changes() -> void:
	if vision_shape.radius != settings.vision_radius:
		vision_shape.radius = settings.vision_radius


## Goes once over all visible boids and collects everything the steering rules need.
func scan_neighbors() -> void:
	neighbor_count = 0
	neighbor_velocity_sum = Vector2.ZERO
	neighbor_position_sum = Vector2.ZERO
	separation_push = Vector2.ZERO
	overlap_push = Vector2.ZERO
	hunter_threat = Vector2.ZERO
	scan_start()

	var separation_radius_squared: float = settings.separation_radius * settings.separation_radius
	var min_distance: float = BODY_RADIUS * 2.0

	# Backwards, so deleted boids can be removed from the list while looping
	for i in range(visible_boids.size() - 1, -1, -1):
		var other: Object = visible_boids[i]
		if not is_instance_valid(other):
			visible_boids.remove_at(i)
			continue
		var boid: Boid = other as Boid
		if boid.state != State.FLYING:
			continue

		var offset: Vector2 = global_position - boid.global_position
		var distance_squared: float = offset.length_squared()
		if not is_same_flock(boid):
			scan_other(boid, offset, distance_squared)
			continue

		# Alignment and cohesion use every visible neighbor of the own flock
		neighbor_count += 1
		neighbor_velocity_sum += boid.velocity
		neighbor_position_sum += boid.global_position

		# Separation only uses neighbors inside the personal space, closer ones push much stronger
		if distance_squared < separation_radius_squared and distance_squared > 0.0:
			separation_push += offset / distance_squared

		# Overlap: each of the two boids moves half of the overlap, together they end up exactly touching
		if distance_squared < min_distance * min_distance:
			var distance: float = sqrt(distance_squared)
			# Boids exactly on top of each other have no direction to push in, so a random one is used
			var direction: Vector2 = offset / distance if distance > 0.0 else Vector2.RIGHT.rotated(randf() * TAU)
			overlap_push += direction * (min_distance - distance) * 0.5


## Called at the start of every scan, lets subclasses like Hunter reset their own results.
func scan_start() -> void:
	pass


## Called by scan_neighbors() for every visible boid of another flock. Normal boids remember hunters to flee
## from them, the Hunter class overrides this to look for prey instead.
func scan_other(boid: Boid, offset: Vector2, distance_squared: float) -> void:
	if boid is Hunter and distance_squared > 0.0:
		# Closer hunters are much scarier
		hunter_threat += offset / distance_squared


## Returns true if the other boid belongs to the same flock (only those flock together).
func is_same_flock(other: Boid) -> bool:
	return other.flock == flock


## Returns the steering force needed to turn the current velocity toward the given direction.
func steer_towards(direction: Vector2) -> Vector2:
	if direction.is_zero_approx():
		return Vector2.ZERO
	return direction.normalized() * settings.speed - velocity


## Alignment, cohesion and separation, calculated from the results of scan_neighbors().
func flocking_force() -> Vector2:
	if neighbor_count == 0:
		return Vector2.ZERO
	# Alignment: Match flight direction with neighbors
	var force: Vector2 = steer_towards(neighbor_velocity_sum) * settings.alignment_weight
	# Cohesion: Move toward the center of mass of neighbors
	force += steer_towards(neighbor_position_sum / neighbor_count - global_position) * settings.cohesion_weight
	# Separation: Steer away to avoid crowding neighbors
	force += steer_towards(separation_push) * settings.separation_weight
	return force


## Extra steering that makes this kind of boid special. Normal boids flee from the hunters they can see,
## the Hunter class overrides this to chase its prey instead.
func behavior_force() -> Vector2:
	return steer_towards(hunter_threat) * settings.flee_weight


## Gently pulls the boid toward the center of its whole flock, so separated groups find back together.
func flock_pull_force() -> Vector2:
	if flock == null:
		return Vector2.ZERO
	return steer_towards(flock.center - global_position) * settings.flock_pull_weight


## Steers toward where the player points the mouse, stronger the further the mouse is from the screen center.
## Near a wall the force is turned along the wall instead of pushing the boid into it.
func player_force() -> Vector2:
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


## Casts a fan of rays in flight direction and sums up the normals of the walls they hit,
## weighted by how close the wall is. Only runs every WALL_CHECK_INTERVAL physics steps.
func update_wall_push() -> void:
	if (Engine.get_physics_frames() + wall_check_offset) % WALL_CHECK_INTERVAL != 0:
		return
	wall_push = Vector2.ZERO
	var heading: float = velocity.angle()
	for i in WALL_RAY_COUNT:
		# -1 for the leftmost ray, 0 for the middle one, +1 for the rightmost ray
		var side: float = lerpf(-1.0, 1.0, float(i) / (WALL_RAY_COUNT - 1))
		var angle: float = heading + deg_to_rad(settings.wall_ray_spread) * side
		var length: float = settings.wall_look_ahead * lerpf(1.0, SIDE_RAY_LENGTH_FACTOR, absf(side))
		var hit: Dictionary = cast_wall_ray(global_position, global_position + Vector2.RIGHT.rotated(angle) * length)
		if hit.is_empty():
			continue
		var distance: float = global_position.distance_to(hit["position"])
		# Grows linearly from 0 at the end of the ray to 1 directly at the wall
		var proximity: float = 1.0 - clampf(distance / length, 0.0, 1.0)
		wall_push += (hit["normal"] as Vector2) * proximity
	wall_push *= settings.speed


## Returns true if the boid's tip would touch a wall during this step's movement.
func hits_wall_ahead() -> bool:
	var tip: Vector2 = global_position + velocity + velocity.normalized() * NOSE_LENGTH
	return not cast_wall_ray(global_position, tip).is_empty()


## Called when the boid is killed (by a hunter, or by a wall if lethal_walls is on): it leaves its flock and disappears.
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


## Pushes the boid out of every neighbor of its flock it overlaps with (collected in scan_neighbors()),
## so two boids never share the same space.
func resolve_overlaps() -> void:
	if not overlap_push.is_zero_approx():
		global_position += clip_against_walls(overlap_push, false)


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
