class_name Boid
extends Area2D

# distance the boid keeps from a wall it slides along
const WALL_SKIN: float = 2.0
# number of wall detection rays, spread evenly from left to right
const WALL_RAY_COUNT: int = 7
# length of the outermost side rays relative to the forward ray
const SIDE_RAY_LENGTH_FACTOR: float = 0.6

# physics layers the boid can't fly through (the level TileMapLayer is on layer 1 "Walls")
@export_flags_2d_physics var wall_collision_mask: int = 1

## Shared tuning values, assigned by the spawner. Falls back to the defaults when the scene runs on its own.
var settings: BoidSettings

# circle shape of the "Vision" area, its radius follows settings.vision_radius
@onready var vision_shape: CircleShape2D = $Vision/CollisionShape2D.shape
# wall detection rays, created in code so their length and angle can be tuned in the settings
var rays: Array[RayCast2D] = []
var visible_boids: Array[Boid] = []
# current velocity vector of boid
var velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()

	create_rays()
	randomize()

	# Assigns a random initial flight direction and normalizes it to match speed
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * settings.speed


func _physics_process(_delta: float) -> void:
	# Applies slider changes from the settings panel
	vision_shape.radius = settings.vision_radius
	update_rays()

	var steering: Vector2 = flocking_force() + wall_force() * settings.wall_avoidance_weight

	# Limits how much the velocity can change per frame, which smooths out sudden turns
	velocity += steering.limit_length(settings.max_steer_force)
	if velocity.is_zero_approx():
		velocity = Vector2.RIGHT.rotated(rotation)

	# Enforces constant speed
	velocity = velocity.normalized() * settings.speed
	move()

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


## Points the rays fan-shaped to the front: the middle ray is the longest, the outer ones are shorter.
func update_rays() -> void:
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
		var distance_squared: float = offset.length_squared()
		if distance_squared > 0.0:
			# Closer neighbors push away much stronger
			separation += offset / distance_squared
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


## Drops neighbors that were deleted (e.g. when the boid count is lowered) without leaving the vision area.
func remove_freed_boids() -> void:
	for i in range(visible_boids.size() - 1, -1, -1):
		if not is_instance_valid(visible_boids[i]):
			visible_boids.remove_at(i)


## Moves the boid and slides along walls instead of passing through them.
func move() -> void:
	var motion: Vector2 = velocity
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
		velocity = velocity.slide(normal)
		# Flying straight into the wall leaves nothing to slide with, so it turns away instead
		if velocity.is_zero_approx():
			velocity = normal * settings.speed

	global_position += motion


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
