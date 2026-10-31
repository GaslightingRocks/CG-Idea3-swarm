class_name Level
extends Node2D

## Root of every level scene. Tells the game where the swarm starts and where it has to go.
## A new level: duplicate a level scene, edit the LevelWall polygons and move StartZone / GoalZone.

@export var start_zone: StartZone
@export var goal_zone: GoalZone
