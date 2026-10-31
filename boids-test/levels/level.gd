class_name Level
extends Node2D

## Root of every level scene. Tells the game where the swarm starts, where it has to go
## and where the hunters start. A new level: duplicate a level scene, edit the LevelWall polygons
## and move the zones.

@export var start_zone: StartZone
@export var goal_zone: GoalZone
# where the enemy flock spawns, leave empty for a level without hunters
@export var enemy_zone: StartZone
