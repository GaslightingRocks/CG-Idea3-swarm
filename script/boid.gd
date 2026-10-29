class_name Boid
extends CharacterBody2D

const MAX_SPEED = 200.0
const STEER_FORCE = 6.0 

@export var separation_weight: float = 1.5
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var crowd_distance: float = 40.0
@export var gravity_weight: float = 0.8 
@export var follow_mouse_weight: float = 1.5 # Wie stark der Schwarm der Maus folgt

var screen_size: Vector2
var known_neighbors: Array[Boid] = []

var active_gravity_force: Vector2 = Vector2.ZERO
var is_pulled: bool = false 
var is_captured: bool = false 

@onready var vision_area: Area2D = $"Area2D(Vision)"

func _ready() -> void:
	screen_size = get_viewport_rect().size
	rotation = randf_range(0, 2 * PI)
	velocity = transform.x * MAX_SPEED

func _physics_process(delta: float) -> void:
	update_neighbors()
	
	var acceleration = Vector2.ZERO
	
	# --- 1. MAUS ALS LEITTIER (Ganz am Anfang, damit die Beschleunigung wirkt) ---
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = get_global_mouse_position()
		var to_mouse = mouse_pos - global_position
		if to_mouse.length() > 10:
			var mouse_force = to_mouse.normalized() * MAX_SPEED
			acceleration += mouse_force * follow_mouse_weight
	
	# --- 2. SCHWARM-KRÄFTE ---
	if known_neighbors.size() > 0:
		var separation = Vector2.ZERO
		var alignment = Vector2.ZERO
		var cohesion = Vector2.ZERO
		var valid_neighbors_count = 0 
		
		for neighbor in known_neighbors:
			# Wenn der Nachbar im Sog des Schwarzen Lochs hängt, ignorieren wir ihn
			if neighbor.is_pulled:
				continue
				
			var distance = global_position.distance_to(neighbor.global_position)
			
			if distance < crowd_distance and distance > 0:
				var diff = global_position - neighbor.global_position
				separation += diff.normalized() / distance 
			
			alignment += neighbor.velocity
			cohesion += neighbor.global_position
			valid_neighbors_count += 1
			
		if valid_neighbors_count > 0:
			alignment = (alignment / valid_neighbors_count).normalized() * MAX_SPEED
			cohesion = (cohesion / valid_neighbors_count)
			cohesion = (cohesion - global_position).normalized() * MAX_SPEED
		
		acceleration += separation * separation_weight * 50.0 
		acceleration += alignment * alignment_weight
		acceleration += cohesion * cohesion_weight
	else:
		if acceleration == Vector2.ZERO:
			acceleration = transform.x * MAX_SPEED
		
	# --- 3. EXTERNE GRAVITATION (SCHWARZES LOCH) ---
	if active_gravity_force != Vector2.ZERO:
		acceleration += active_gravity_force * gravity_weight

	# Bewegung anpassen
	velocity = velocity.lerp(acceleration, delta * STEER_FORCE)
	velocity = velocity.limit_length(MAX_SPEED)
	
	if velocity.length() > 0:
		rotation = velocity.angle()
		
	move_and_slide()
	
	# WICHTIG: Erst am ENDE des Frames zurücksetzen, damit der Zustand im aktuellen Frame gültig bleibt!
	active_gravity_force = Vector2.ZERO
	is_pulled = false 
	is_captured = false

# Wird vom Gravitations-Objekt aufgerufen
func apply_external_gravity(target_position: Vector2, strength: float) -> void:
	is_pulled = true 
	
func update_neighbors() -> void:
	known_neighbors.clear()
	for body in vision_area.get_overlapping_bodies():
		if body is Boid and body != self:
			known_neighbors.append(body)
