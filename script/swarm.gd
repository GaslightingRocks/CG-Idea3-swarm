class_name Swarm
extends Node2D
## Zentraler Schwarm-Manager.
##
## WARUM GIBT ES DAS?
## Vorher hatte jeder Boid eine eigene Area2D als "Sicht" und hat jeden Physik-Frame
## get_overlapping_bodies() aufgerufen. Das ist teuer: Die Physik-Engine muss für jede
## Area alle Überlappungen verwalten, und GDScript baut pro Boid und Frame ein neues Array.
##
## JETZT: Der Swarm kennt alle Boids und sortiert sie einmal pro Physik-Frame in ein
## grobes Raster ("Spatial Hash"). Ein Boid fragt dann nur noch die 1-4 Rasterzellen um
## sich herum ab, statt alle Boids zu prüfen oder die Physik zu bemühen.
##
## Außerdem liest der Swarm die Maus EINMAL pro Frame, statt dass jeder Boid das einzeln tut.

## Gruppenname, über den Boids und GravityPoints den Swarm finden.
const GROUP := &"swarm"

@export_group("Spawnen")
## Boid-Szene, die beim Start erzeugt wird. Leer lassen, wenn du Boids von Hand platzierst.
@export var boid_scene: PackedScene
## Wie viele Boids der Swarm beim Start selbst erzeugt.
@export var spawn_count: int = 0
## Bereich (in Weltkoordinaten), in dem zufällig gespawnt wird.
@export var spawn_rect: Rect2 = Rect2(40, 40, 1840, 1000)
## Welche Physik-Layer als "Wand" gelten (Spawnpunkte in Wänden werden verworfen).
## Im TileSet ist Layer 3 (Wert 4) eingestellt.
@export_flags_2d_physics var wall_mask: int = 4
## Mindestabstand zur Wand beim Spawnen in Pixeln.
@export var spawn_clearance: float = 12.0

@export_group("Raster")
## Kantenlänge einer Rasterzelle. Sollte etwa so groß sein wie der größte Sichtradius,
## dann reichen 3x3 Zellen immer aus. Zu klein = mehr Zellen pro Abfrage, zu groß = mehr
## Boids pro Zelle.
@export var cell_size: float = 64.0

## Alle aktiven Boids (wird von Boid._ready() / _exit_tree() gepflegt).
var boids: Array[Boid] = []

## Linke Maustaste gedrückt? Wird einmal pro Frame hier gesetzt, Boids lesen nur noch.
var mouse_pull_active: bool = false
## Mausposition in Weltkoordinaten (Kamera/Zoom werden berücksichtigt).
var mouse_pull_position: Vector2 = Vector2.ZERO

## Raster: Vector2i (Zellkoordinate) -> Array[Boid]. Die Arrays werden jeden Frame
## geleert und neu gefüllt statt neu erzeugt (spart Speicherallokationen).
var _grid: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)
	# Der Swarm muss VOR den Boids rechnen, egal wo er im Szenenbaum steht:
	# Kleinere Priorität = früher dran.
	process_physics_priority = -10


func _ready() -> void:
	if boid_scene != null and spawn_count > 0:
		_spawn_boids()


func _physics_process(_delta: float) -> void:
	mouse_pull_active = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	mouse_pull_position = get_global_mouse_position()
	_rebuild_grid()


# --- Registrierung -----------------------------------------------------------------

func register(boid: Boid) -> void:
	boids.append(boid)


func unregister(boid: Boid) -> void:
	boids.erase(boid)


# --- Nachbarschaftsabfrage ---------------------------------------------------------

## Schreibt alle Boids im Umkreis `radius` um `center` nach `out` (wird vorher geleert).
## `exclude` wird übersprungen (typisch: der fragende Boid selbst).
## `out` wird vom Aufrufer wiederverwendet -> keine neue Array-Allokation pro Abfrage.
func query_radius(center: Vector2, radius: float, out: Array[Boid], exclude: Boid = null) -> void:
	out.clear()
	var radius_sq := radius * radius

	# Welche Rasterzellen deckt der Kreis ab? (Bounding-Box des Kreises)
	var cell_min := Vector2i(((center - Vector2(radius, radius)) / cell_size).floor())
	var cell_max := Vector2i(((center + Vector2(radius, radius)) / cell_size).floor())

	for cy in range(cell_min.y, cell_max.y + 1):
		for cx in range(cell_min.x, cell_max.x + 1):
			var cell: Variant = _grid.get(Vector2i(cx, cy))
			if cell == null:
				continue
			for boid: Boid in cell:
				if boid != exclude and center.distance_squared_to(boid.global_position) <= radius_sq:
					out.append(boid)


func _rebuild_grid() -> void:
	# Zellen leeren, aber die Array-Objekte behalten.
	for cell: Array in _grid.values():
		cell.clear()

	for boid in boids:
		var key := Vector2i((boid.global_position / cell_size).floor())
		var cell: Variant = _grid.get(key)
		if cell == null:
			cell = []
			_grid[key] = cell
		cell.append(boid)


# --- Spawnen -----------------------------------------------------------------------

func _spawn_boids() -> void:
	# Die Wand-Collider des TileMapLayers existieren erst nach ein bis zwei Physik-Frames
	# in der Physik-Engine. Vorher würden Abfragen "alles frei" melden.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = spawn_clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = wall_mask

	var spawned := 0
	var attempts := 0
	while spawned < spawn_count and attempts < spawn_count * 50:
		attempts += 1
		var pos := Vector2(
			randf_range(spawn_rect.position.x, spawn_rect.end.x),
			randf_range(spawn_rect.position.y, spawn_rect.end.y))
		query.transform = Transform2D(0.0, pos)
		# Treffer = Wand in der Nähe -> Punkt verwerfen und neu würfeln.
		if not space.intersect_shape(query, 1).is_empty():
			continue

		var boid := boid_scene.instantiate() as Boid
		boid.swarm = self
		add_child(boid)
		boid.global_position = pos
		spawned += 1

	if spawned < spawn_count:
		push_warning("Swarm: nur %d von %d Boids konnten gespawnt werden (spawn_rect zu klein?)." % [spawned, spawn_count])
