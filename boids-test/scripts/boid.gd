class_name Boid
extends Area2D

## Shared tuning values, assigned by the spawner. Falls back to the defaults when the scene runs on its own.
var settings: BoidSettings

@onready var rays: Array[Node] = $RayFolder.get_children()
var visible_boids: Array[Boid] = []
# current velocity vector of boid
var velocity: Vector2 = Vector2.ZERO
var screen_size: Vector2


func _ready() -> void:
	if settings == null:
		settings = BoidSettings.new()

	# Fetches the window boundaries at startup
	screen_size = get_viewport_rect().size
	randomize()

	# Assigns a random initial flight direction and normalizes it to match speed
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * settings.speed


func _physics_process(_delta: float) -> void:
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
			var ray_length: float = (ray.to_global(ray.target_position) - ray.global_position).length()
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


## Moves the boid and wraps its position around screen edges if it goes out of bounds.
func move() -> void:
	global_position += velocity

	if global_position.x < 0:
		global_position.x = screen_size.x
	if global_position.x > screen_size.x:
		global_position.x = 0
	if global_position.y < 0:
		global_position.y = screen_size.y
	if global_position.y > screen_size.y:
		global_position.y = 0


## Adds a neighboring boid to the tracking array when it enters the vision area.
func _on_vision_area_entered(area: Area2D) -> void:
	if area != self and area is Boid:
		visible_boids.append(area)


## Removes a boid from the tracking array when it leaves the vision area.
func _on_vision_area_exited(area: Area2D) -> void:
	if area is Boid:
		visible_boids.erase(area)
