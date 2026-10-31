class_name LevelWall
extends Polygon2D

## A piece of level geometry, drawn as a polygon. At runtime it creates its own collision from the
## same points, so what you see is always exactly what the boids collide with.
##
## Editing: select the node in the scene tree, then drag, add (click on an edge) or remove (right click)
## points directly in the 2D view.
##
## is_cave_outline = true:  the polygon is the open cave, everything outside of it is rock.
##                          The collision is only the outline (a closed chain of line segments).
## is_cave_outline = false: the polygon is a solid rock inside the cave.

# true for the polygon that outlines the open cave, false for solid rocks inside it
@export var is_cave_outline: bool = false
# physics layer of the generated collision (layer 1 "Walls", which the boids' rays look for)
@export_flags_2d_physics var collision_layer: int = 1


func _ready() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = collision_layer
	body.collision_mask = 0
	# The boids only avoid colliders in the "blocks" group
	body.add_to_group("blocks")

	var shape: CollisionPolygon2D = CollisionPolygon2D.new()
	shape.polygon = polygon
	if is_cave_outline:
		shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	body.add_child(shape)
	add_child(body)
