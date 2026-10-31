class_name Boid
extends Area2D

# constant movement speed (pixels per physics frame)
@export var speed: float = 5.0
# how strongly the boid matches the average velocity of its neighbors
@export var alignment_weight: float = 0.5
# how strongly the boid moves toward the center of mass of its neighbors
@export var cohesion_weight: float = 1.0
# weight/multiplier used for calculating separation force from neighboring boids
@export var separation_weight: float = 48.0
# how fast the rotation follows the velocity (0 = never, 1 = instantly)
@export_range(0.0, 1.0) var rotation_smoothing: float = 0.4

@onready var rays: Array[Node] = $RayFolder.get_children()
var visible_boids: Array[Boid] = []
# current velocity vector of boid
var velocity: Vector2 = Vector2.ZERO
var screen_size: Vector2


func _ready() -> void:
	# Fetches the window boundaries at startup
	screen_size = get_viewport_rect().size
	randomize()

	# Assigns a random initial flight direction and normalizes it to match speed
	velocity = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * speed


func _physics_process(_delta: float) -> void:
	apply_flocking()
	avoid_walls()

	# Enforces constant speed
	velocity = velocity.normalized() * speed
	move()

	# Smoothly interpolates the rotation angle toward the current velocity vector
	rotation = lerp_angle(rotation, velocity.angle(), rotation_smoothing)


## Calculates flocking forces (alignment, cohesion, and separation) based on visible neighbors.
func apply_flocking() -> void:
	if visible_boids.is_empty():
		return

	var boid_count: int = visible_boids.size()
	var avg_velocity: Vector2 = Vector2.ZERO
	var avg_position: Vector2 = Vector2.ZERO
	var steer_away: Vector2 = Vector2.ZERO
	for boid: Boid in visible_boids:
		avg_velocity += boid.velocity
		avg_position += boid.global_position
		var offset: Vector2 = boid.global_position - global_position
		var distance: float = offset.length()
		if distance > 0.0:
			steer_away -= offset * (separation_weight / distance)

	# Alignment: Match velocity with neighbors
	avg_velocity /= boid_count
	velocity += (avg_velocity - velocity) * alignment_weight

	# Cohesion: Move toward the center of mass of neighbors
	avg_position /= boid_count
	velocity += (avg_position - global_position) * cohesion_weight

	# Separation: Steer away to avoid crowding neighbors
	steer_away /= boid_count
	velocity += steer_away


## Uses raycasts to detect walls in the "blocks" group and steers the boid away from them.
func avoid_walls() -> void:
	for ray: RayCast2D in rays:
		if ray.is_colliding() and ray.get_collider().is_in_group("blocks"):
			# Changing number affects jitteriness
			var strength: float = 1.0 / (ray.get_collision_point() - global_position).length_squared()
			velocity -= ray.target_position.rotated(rotation) * strength


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
