extends Area2D

@onready var rayFolder := $rayFolder.get_children()
var boidsISee := []
# current velocity vector of boid
var vel := Vector2.ZERO
var speed := 5.0
var screensize : Vector2
# weight/multiplier used for calculating separation force from neighboring boids
var movv := 48


func _ready() -> void:
	# Fetches the window boundaries at startup
	screensize = get_viewport_rect().size
	randomize() 
	
	# Assigns a random initial flight direction and normalizes it to match speed
	vel = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * speed


func _physics_process(_delta: float) -> void:
	boids()
	checkCollision()
	
	# Enforces constant speed
	vel = vel.normalized() * speed
	move()
	
	# Smoothly interpolates the rotation angle toward the current velocity vector
	rotation = lerp_angle(rotation, vel.angle(), 0.4)
	
	# Optional rotation clamping experiment (uncomment if you want to test it)
	# clamp_rotation()

## Calculates flocking forces (alignment, cohesion, and separation) based on visible neighbors.
func boids() -> void:
	if boidsISee:
		var numOfBoids := boidsISee.size()
		var avgVel := Vector2.ZERO
		var avgPos := Vector2.ZERO
		var steerAway := Vector2.ZERO
		for boid in boidsISee:
			avgVel += boid.vel
			avgPos += boid.position
			steerAway -= (boid.global_position - global_position) * (movv/( global_position- boid.global_position).length())

		# Alignment: Match velocity with neighbors
		avgVel /= numOfBoids
		vel += (avgVel - vel) / 2

		# Cohesion: Move toward the center of mass of neighbors
		avgPos /= numOfBoids
		vel += (avgPos - position)

		# Separation: Steer away to avoid crowding neighbors
		steerAway /= numOfBoids
		vel += (steerAway)


## Uses raycasts to detect walls in the "blocks" group and steers the boid away from them.
func checkCollision() -> void:
	for ray in rayFolder:
		var r : RayCast2D = ray
		if r.is_colliding():
			if r.get_collider().is_in_group("blocks"):
				# Changing number affects jitteriness
				var magi := (1 / (r.get_collision_point() - global_position).length_squared())
				vel -= (r.target_position.rotated(rotation) * magi)
		pass


## Moves the boid and wraps its position around screen edges if it goes out of bounds.
func move() -> void:
	global_position += vel
	
	if global_position.x < 0:
		global_position.x = screensize.x 
	if global_position.x > screensize.x:
		global_position.x = 0
	if global_position.y < 0:
		global_position.y = screensize.y 
	if global_position.y > screensize.y:
		global_position.y = 0


## Adds a neighboring boid to the tracking array when it enters the vision area.
func _on_vision_area_entered(area: Area2D) -> void:
	if area != self and area.is_in_group("boid"):
		boidsISee.append(area)


## Removes a boid from the tracking array when it leaves the vision area.
func _on_vision_area_exited(area: Area2D) -> void:
	if area:
		boidsISee.erase(area)


## Triggered if the boid body physically hits something.
func _on_boid_body_entered(body: Node) -> void:
	if body:
		print("hit smth :(")
