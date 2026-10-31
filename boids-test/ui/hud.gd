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
	counts_label.text = "Unterwegs: %d\nGerettet: %d\nVerloren: %d\nJäger: %d\nStreuner: %d\n\nR: Neustart" % [flying, saved, lost, hunters, strays]


## Shows a message in the middle of the screen, an empty text hides it.
func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = text != ""


## Shows the summed up courage of the swarm and how much it could have at most (every boid fully brave).
func show_courage(total: float, maximum: int) -> void:
	courage_label.text = "Mut: %d / %d" % [roundi(total), maximum]


## Shows the ability keys, costs and which ability is running.
func show_abilities(text: String) -> void:
	abilities_label.text = text
