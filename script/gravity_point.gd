class_name GravityPoint
extends Node2D
## Schwarzes Loch: fängt die nächstgelegenen Boids ein und hält sie in einem kleinen Ring
## um sein Zentrum. Es können nur `max_boids` gleichzeitig festgehalten werden ("Sättigung"),
## alle anderen fliegen unbeeinflusst vorbei.
##
## Geändert gegenüber der ersten Version:
##  - Keine Area2D mehr. Der Einfangbereich ist jetzt `capture_radius`, die Boids werden
##    über den Swarm gesucht. Die Area2D + CollisionShape2D unter diesem Node können gelöscht
##    werden (weniger Physik-Objekte).
##  - Kein filter()/sort_custom() mit Lambda mehr in jedem Frame (das erzeugt jedes Mal
##    neue Arrays und Callables). Stattdessen einfache Schleifen.
##  - Ein Boid, der festgehalten wird, hat is_pulled = true, bis dieser Punkt ihn wieder
##    freigibt. Das Flag flackert nicht mehr.

## Maximale Anzahl gleichzeitig festgehaltener Boids.
@export var max_boids: int = 5
## Reichweite, in der Boids eingefangen werden (px). Entspricht der alten Area2D
## (Radius 10 * Scale 5 * Scale 1,235 = ~62).
@export var capture_radius: float = 62.0
## Radius des innersten Rings, auf dem die gefangenen Boids sitzen (px).
@export var ring_radius: float = 15.0
## Jeder weitere Boid sitzt um so viel weiter außen (px), damit sie nicht aufeinander hocken.
@export var ring_step: float = 2.0
## Wie stark ein festgehaltener Boid pro Physik-Frame zu seinem Platz gezogen wird (0..1).
@export_range(0.0, 1.0) var snap_factor: float = 0.1
## Einfangbereich im Spiel als dünner Kreis anzeigen (zum Einstellen praktisch).
@export var show_radius: bool = true

## Aktuell festgehaltene Boids.
var captured: Array[Boid] = []

var _swarm: Swarm
var _candidates: Array[Boid] = []   # wiederverwendetes Suchergebnis


func _ready() -> void:
	_swarm = get_tree().get_first_node_in_group(Swarm.GROUP) as Swarm
	if _swarm == null:
		push_error("GravityPoint: kein Swarm in der Szene gefunden.")
		set_physics_process(false)


func _draw() -> void:
	if show_radius:
		draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 1.0)


func _physics_process(_delta: float) -> void:
	_release_boids_out_of_range()
	if captured.size() < max_boids:
		_capture_nearest_boids()
	_hold_captured_boids()


## 1. Boids rauswerfen, die ungültig geworden sind (gelöscht) oder zu weit weg sind.
func _release_boids_out_of_range() -> void:
	var radius_sq := capture_radius * capture_radius
	# Rückwärts laufen, damit remove_at() die noch unbesuchten Einträge nicht verschiebt.
	for i in range(captured.size() - 1, -1, -1):
		var boid := captured[i]
		if not is_instance_valid(boid):
			captured.remove_at(i)
		elif global_position.distance_squared_to(boid.global_position) > radius_sq:
			boid.is_pulled = false
			captured.remove_at(i)


## 2. Freie Plätze mit den nächsten, noch freien Boids auffüllen.
func _capture_nearest_boids() -> void:
	_swarm.query_radius(global_position, capture_radius, _candidates)

	while captured.size() < max_boids:
		var nearest: Boid = null
		var nearest_dist_sq := INF
		for candidate in _candidates:
			# is_pulled = wird schon von diesem oder einem anderen GravityPoint gehalten.
			if candidate.is_pulled:
				continue
			var d := global_position.distance_squared_to(candidate.global_position)
			if d < nearest_dist_sq:
				nearest_dist_sq = d
				nearest = candidate
		if nearest == null:
			break   # niemand mehr in Reichweite
		nearest.is_pulled = true
		captured.append(nearest)


## 3. Gefangene Boids sanft auf ihre Plätze im Ring ziehen.
func _hold_captured_boids() -> void:
	var total := captured.size()
	for i in total:
		var boid := captured[i]
		var angle := (float(i) / total) * TAU
		var slot := global_position + Vector2.from_angle(angle) * (ring_radius + i * ring_step)
		boid.global_position = boid.global_position.lerp(slot, snap_factor)
		boid.velocity = boid.velocity.lerp(Vector2.ZERO, snap_factor)
