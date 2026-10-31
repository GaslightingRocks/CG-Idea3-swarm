class_name Hunter
extends Boid

## An enemy boid. Flies together with the other hunters of its flock, chases the nearest prey it can see
## and kills it on contact, dying itself in the process.
## Prey is every boid of another flock that is not a hunter itself.
## Everything else (walls, steering, settings) works exactly like a normal Boid, because Hunter extends Boid.


func _physics_process(delta: float) -> void:
	# Runs the normal boid movement first ("super" calls the Boid version of this function)
	super(delta)
	if state == State.FLYING:
		check_contact()


## Hunters don't flee, they steer toward the nearest prey instead.
func behavior_force() -> Vector2:
	var prey: Boid = nearest_prey()
	if prey == null:
		return Vector2.ZERO
	return steer_towards(prey.global_position - global_position) * settings.chase_weight


## Returns the closest visible prey, or null if the hunter sees none.
func nearest_prey() -> Boid:
	var nearest: Boid = null
	var nearest_distance: float = INF
	for boid: Boid in visible_boids:
		if not is_prey(boid):
			continue
		var distance: float = global_position.distance_to(boid.global_position)
		if distance < nearest_distance:
			nearest = boid
			nearest_distance = distance
	return nearest


## Prey is a still flying boid of another flock that isn't a hunter.
func is_prey(boid: Boid) -> bool:
	return is_instance_valid(boid) and boid.state == State.FLYING and not is_same_flock(boid) and not (boid is Hunter)


## Kills the first prey that touches this hunter, and the hunter itself.
func check_contact() -> void:
	for boid: Boid in visible_boids:
		if is_prey(boid) and global_position.distance_to(boid.global_position) < BODY_RADIUS * 2.0:
			boid.die()
			die()
			return
