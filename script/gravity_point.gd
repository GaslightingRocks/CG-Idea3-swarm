class_name GravityPoint
extends Node2D

@export var max_boids: int = 5        # Maximale Anzahl an fest gebundenen Boids
@export var pull_strength: float = 200.0 

@onready var area_2d: Area2D = $Area2D 

var current_pulled_boids: Array[Boid] = []

func _physics_process(delta: float) -> void:
	if not area_2d:
		return
		
	# 1. Boids, die nicht mehr im Area2D sind oder ungültig wurden, rauswerfen
	current_pulled_boids = current_pulled_boids.filter(func(b):
		return is_instance_valid(b) and area_2d.overlaps_body(b)
	)
	
	# 2. Neue Boids aus dem Umkreis holen, solange wir unter dem Limit (Sättigung) sind
	var overlapping_bodies = area_2d.get_overlapping_bodies()
	var available_boids: Array[Boid] = []
	
	for body in overlapping_bodies:
		if body is Boid and not current_pulled_boids.has(body):
			# Nur Boids einsammeln, die nicht bereits von einem anderen Punkt gehalten werden
			available_boids.append(body)
			
	# Nach Entfernung sortieren (die Nächsten zuerst)
	available_boids.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	
	# Plätze auffüllen bis `max_boids` erreicht ist
	for boid in available_boids:
		if current_pulled_boids.size() < max_boids:
			current_pulled_boids.append(boid)
		else:
			break 
			
	# 3. Festhalten-Logik: Zwinge die gebundenen Boids direkt zum Zentrum des Schwarzen Lochs
	for i in range(current_pulled_boids.size()):
		var boid = current_pulled_boids[i]
		
		# Wir sagen dem Boid, dass er im Sog ist (für den Schwarm-Filter)
		boid.is_pulled = true
		
		# Wir verteilen die Boids in einem kleinen Kreis um das Zentrum (damit sie nicht alle exakt aufeinander hocken)
		var angle = (i / float(current_pulled_boids.size())) * PI * 2.0
		var offset = Vector2(cos(angle), sin(angle)) * (15.0 + (i * 2.0))
		var target_pos = global_position + offset
		
		# Boid direkt sanft zum Zielpunkt ziehen und Geschwindigkeit dämpfen
		boid.global_position = boid.global_position.lerp(target_pos, 0.1)
		boid.velocity = boid.velocity.lerp(Vector2.ZERO, 0.1)
