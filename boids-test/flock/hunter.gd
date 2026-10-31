class_name Hunter
extends Boid

## An enemy boid. Flies together with the other hunters of its flock, chases the nearest prey it can see
## and kills it on contact. Every kill costs the hunter one of its lives (settings.hunter_lives).
## Prey is every boid of another flock that is not a hunter itself.
## Everything else (walls, steering, settings) works exactly like a normal Boid, because Hunter extends Boid.

# center distance (in pixels) at which hunter and prey touch: hunter radius 7 + prey radius 5
const CONTACT_DISTANCE: float = 12.0
# physics steps after a kill in which the hunter can't kill again, so it can't wipe out a cluster at once
const HIT_COOLDOWN_STEPS: int = 20
# how much darker the hunter gets per lost life
const DARKEN_PER_HIT: float = 0.3

# remaining lives, the hunter dies when they reach 0
var lives: int = 1
var hit_cooldown: int = 0
# closest visible prey of the current physics step, found in scan_neighbors()
var nearest_prey: Boid = null
var nearest_prey_distance_squared: float = INF


func _ready() -> void:
	# Runs the normal boid setup first ("super" calls the Boid version of this function)
	super()
	lives = settings.hunter_lives


func _physics_process(delta: float) -> void:
	super(delta)
	if hit_cooldown > 0:
		hit_cooldown -= 1
	elif state == State.FLYING:
		check_contact()


func scan_start() -> void:
	nearest_prey = null
	nearest_prey_distance_squared = INF


## Remembers the closest prey instead of fleeing from hunters like a normal boid.
func scan_other(boid: Boid, _offset: Vector2, distance_squared: float) -> void:
	if boid is Hunter:
		return
	if distance_squared < nearest_prey_distance_squared:
		nearest_prey = boid
		nearest_prey_distance_squared = distance_squared


## Hunters don't flee, they steer toward the nearest prey instead.
func behavior_force() -> Vector2:
	if nearest_prey == null:
		return Vector2.ZERO
	return steer_towards(nearest_prey.global_position - global_position) * settings.chase_weight


## Kills the nearest prey if it touches the hunter. The hunter loses a life and dies when none are left.
func check_contact() -> void:
	if nearest_prey == null or not is_instance_valid(nearest_prey) or nearest_prey.state != State.FLYING:
		return
	if global_position.distance_to(nearest_prey.global_position) > CONTACT_DISTANCE:
		return

	nearest_prey.die()
	nearest_prey = null
	lives -= 1
	if lives <= 0:
		die()
	else:
		hit_cooldown = HIT_COOLDOWN_STEPS
		modulate = modulate.darkened(DARKEN_PER_HIT)
