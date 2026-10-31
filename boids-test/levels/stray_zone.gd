@tool
class_name StrayZone
extends StartZone

## A group of stray boids waiting somewhere in the level. They circle around this spot
## and join the player's swarm when it comes close. Add as many as you like to a level.
## Works like a StartZone (move the node, change radius), plus the number of strays.

# number of strays in this group
@export var boid_count: int = 8


func _init() -> void:
	# Defaults for new stray zones, values saved in the level scene overwrite them
	label = "STREUNER"
	color = Color(0.6, 0.7, 1.0, 0.2)
