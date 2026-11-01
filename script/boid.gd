class_name Boid
extends CharacterBody2D
## Ein einzelnes Wesen des Schwarms.
##
## Die Steuerung ist wie vorher: Jede Regel (Maus, Trennung, Ausrichtung, Zusammenhalt)
## liefert eine "Wunschgeschwindigkeit". Diese werden gewichtet addiert, und die echte
## Geschwindigkeit nähert sich dem Ergebnis weich an (lerp).
##
## Geändert gegenüber der ersten Version:
##  - Nachbarn kommen vom Swarm (Spatial Hash) statt von einer Area2D pro Boid.
##  - Die Maus wird vom Swarm einmal pro Frame gelesen, nicht von jedem Boid.
##  - Boids, die vom GravityPoint gehalten werden, steuern sich nicht mehr selbst
##    (vorher haben sie gegen den GravityPoint "gekämpft").
##  - is_pulled wird nur noch vom GravityPoint gesetzt und gelöscht. Vorher hat sich
##    jeder Boid das Flag am Frame-Ende selbst zurückgesetzt, wodurch Nachbarn es je nach
##    Reihenfolge im Szenenbaum mal gesehen haben und mal nicht.

const MAX_SPEED: float = 120.0
## Wie schnell sich die Geschwindigkeit der Wunschgeschwindigkeit annähert (pro Sekunde).
const STEER_FORCE: float = 6.0
## Unterhalb dieses Abstands (px) zur Maus wird nicht mehr zur Maus gesteuert (verhindert Zittern).
const MOUSE_DEAD_ZONE: float = 10.0

@export var max_SPEED: float = 120.0
@export var separation_weight: float = 1.5
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
## Näher als das (px) gilt ein Nachbar als "zu nah" -> Boid weicht aus.
@export var crowd_distance: float = 40.0
## Wie weit der Boid Nachbarn sieht (px, Mittelpunkt zu Mittelpunkt).
## Vorher war das in der Szene versteckt: Die Vision-Area hatte Radius 40 (10 * Scale 4),
## aber get_overlapping_bodies() liefert jeden Körper, dessen FORM die Area berührt.
## Mit dem alten Körperradius 50 ergab das effektiv 40 + 50 = 90 px.
## Ist der Körper kleiner, muss dieser Wert die Sichtweite allein tragen.
@export var vision_radius: float = 90.0
## Wie stark der Boid der Maus folgt, solange links geklickt wird.
@export var follow_mouse_weight: float = 1.5
## Performance-Regler: Die Schwarmregeln (die teuerste Rechnung) werden nur jeden n-ten
## Physik-Frame neu berechnet, dazwischen wird die letzte Wunschgeschwindigkeit weiter
## benutzt. Die Bewegung selbst läuft weiterhin jeden Frame, durch das weiche lerp()
## sieht man davon praktisch nichts. 1 = jeden Frame (wie vorher), 2 = halbe Last, 3 = Drittel.
## Jeder Boid hat eine zufällige Phase, damit nicht alle im selben Frame rechnen.
@export_range(1, 6) var steering_interval: int = 2

## Wird vom GravityPoint gesetzt, solange dieser Boid festgehalten wird.
var is_pulled: bool = false
## Der Swarm, bei dem sich dieser Boid anmeldet. Wird vom Swarm gesetzt, wenn er den Boid
## spawnt; bei von Hand platzierten Boids wird er in _ready() gesucht.
var swarm: Swarm

## Boids in Sichtweite. Das Array wird jeden Frame wiederverwendet (kein neues Array).
var known_neighbors: Array[Boid] = []

## Zuletzt berechnete Wunschgeschwindigkeit (wird zwischen den Neuberechnungen weiterverwendet).
var _desired: Vector2 = Vector2.ZERO
## Zufälliger Versatz, wann dieser Boid im Intervall neu rechnet.
var _phase: int = 0


func _ready() -> void:
	# Top-Down-Spiel: FLOATING statt GROUNDED. Im Grounded-Modus rechnet move_and_slide()
	# Boden/Decke/Schräge-Logik mit, die hier nichts bringt, aber Zeit kostet.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	rotation = randf_range(0.0, TAU)
	velocity = transform.x * MAX_SPEED
	_desired = velocity
	_phase = randi() % maxi(steering_interval, 1)

	if swarm == null:
		swarm = get_tree().get_first_node_in_group(Swarm.GROUP) as Swarm
	if swarm == null:
		push_error("Boid: kein Swarm in der Szene gefunden (Node mit swarm.gd hinzufügen).")
		set_physics_process(false)
		return
	swarm.register(self)


func _exit_tree() -> void:
	if is_instance_valid(swarm):
		swarm.unregister(self)


func _physics_process(delta: float) -> void:
	# Vom GravityPoint gehalten: der bewegt uns, wir machen nichts.
	if is_pulled:
		return

	# Schwarmregeln nur jeden `steering_interval`-ten Frame neu berechnen (siehe Export oben).
	if (Engine.get_physics_frames() + _phase) % steering_interval == 0:
		_desired = _compute_desired_velocity()

	# --- Bewegung (läuft jeden Frame, nutzt die zuletzt berechnete Wunschgeschwindigkeit) ---
	velocity = velocity.lerp(_desired, delta * STEER_FORCE).limit_length(MAX_SPEED)

	if velocity.length_squared() > 0.0:
		rotation = velocity.angle()

	move_and_slide()


## Berechnet die Wunschgeschwindigkeit aus Maus und Schwarmregeln (die teure Rechnung).
func _compute_desired_velocity() -> Vector2:
	swarm.query_radius(global_position, vision_radius, known_neighbors, self)

	# Summe aller Wunschgeschwindigkeiten (im Original "acceleration" genannt, ist aber
	# eigentlich eine Zielgeschwindigkeit, auf die per lerp hingesteuert wird).
	var desired := Vector2.ZERO

	# --- 1. Maus als Anführer ---
	if swarm.mouse_pull_active:
		var to_mouse := swarm.mouse_pull_position - global_position
		if to_mouse.length() > MOUSE_DEAD_ZONE:
			desired += to_mouse.normalized() * MAX_SPEED * follow_mouse_weight

	# --- 2. Schwarmregeln ---
	var separation := Vector2.ZERO
	var alignment := Vector2.ZERO
	var cohesion := Vector2.ZERO
	var count := 0

	for neighbor in known_neighbors:
		# Boids, die im Sog eines GravityPoints hängen, gehören nicht mehr zum Schwarm.
		if neighbor.is_pulled:
			continue

		var diff := global_position - neighbor.global_position
		var dist := diff.length()

		# Trennung: weg von zu nahen Nachbarn, je näher desto stärker (1/Abstand).
		# diff / dist^2 ist dasselbe wie diff.normalized() / dist, spart aber ein sqrt.
		if dist > 0.0 and dist < crowd_distance:
			separation += diff / (dist * dist)

		alignment += neighbor.velocity               # für Ausrichtung: Ø-Richtung der Nachbarn
		cohesion += neighbor.global_position         # für Zusammenhalt: Ø-Position der Nachbarn
		count += 1

	if count > 0:
		alignment = (alignment / count).normalized() * MAX_SPEED
		cohesion = ((cohesion / count) - global_position).normalized() * MAX_SPEED
		desired += separation * separation_weight * 50.0
		desired += alignment * alignment_weight
		desired += cohesion * cohesion_weight

	# Nichts, woran man sich orientieren kann -> geradeaus weiter.
	# (Im Original galt das nur ohne Nachbarn. Waren alle Nachbarn gefangen, blieb
	# desired = 0 und der Boid ist stehen geblieben.)
	if desired == Vector2.ZERO:
		desired = transform.x * MAX_SPEED

	return desired
