class_name Hud
extends Control

## Minimal heads-up display: the boid counters in the top right and a message in the middle of the screen.
## Covers the whole screen but ignores the mouse, so it never blocks clicks.

@onready var counts_label: Label = $Counts
@onready var message_label: Label = $Message
@onready var courage_label: Label = $Courage
@onready var abilities_label: Label = $Abilities


## Shows how many of the player's boids are still flying, saved and lost,
## how many hunters are left and how many strays are still waiting to be collected.
func show_counts(flying: int, saved: int, lost: int, hunters: int, strays: int) -> void:
	counts_label.text = "Flying: %d\nSaved: %d\nLost: %d\nHunters: %d\nStrays: %d\n\nR: Restart" % [flying, saved, lost, hunters, strays]


## Shows a message in the middle of the screen, an empty text hides it.
func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = text != ""


## Shows the swarm's courage pool, how full it can get and whether it is filling right now.
func show_courage(pool: float, maximum: float, filling: bool) -> void:
	var state: String = "" if filling else "  (swarm too scattered)"
	courage_label.text = "Courage: %.1f / %d%s" % [pool, roundi(maximum), state]


## Shows the ability keys, costs and which ability is running.
func show_abilities(text: String) -> void:
	abilities_label.text = text
