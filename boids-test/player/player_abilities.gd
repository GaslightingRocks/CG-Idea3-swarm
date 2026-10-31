class_name PlayerAbilities
extends Node

## The swarm's two special abilities. Both are paid with courage (the sum of all boids' courage, see the HUD).
##
## Dodge ("ability_dodge", Space): the whole swarm dashes in the mouse direction at higher speed,
##     hunters can't catch any boid while it lasts.
## Attack ("ability_attack", left mouse button): the swarm turns on the hunters it sees,
##     every boid touching a hunter costs the hunter a life instead of dying itself.

# flock that uses the abilities
@export var flock: Flock

@export_group("Dodge")
@export var dodge_cost: float = 10.0
# seconds the dodge lasts
@export var dodge_duration: float = 0.6
@export var dodge_speed_multiplier: float = 2.0

@export_group("Attack")
@export var attack_cost: float = 25.0
# seconds the attack lasts
@export var attack_duration: float = 3.0
# how strongly the boids fly at the nearest hunter during the attack
@export var attack_steer_weight: float = 3.0


func _unhandled_input(event: InputEvent) -> void:
	# Both actions are defined in Project Settings > Input Map
	if event.is_action_pressed("ability_dodge"):
		try_dodge()
	elif event.is_action_pressed("ability_attack"):
		try_attack()


## Starts the dodge if it isn't running already and the swarm has enough courage.
func try_dodge() -> void:
	if flock.is_dodging() or not flock.spend_courage(dodge_cost):
		return
	flock.start_dodge(dodge_duration, dodge_speed_multiplier)


## Starts the attack if it isn't running already and the swarm has enough courage.
func try_attack() -> void:
	if flock.is_attacking() or not flock.spend_courage(attack_cost):
		return
	flock.start_attack(attack_duration, attack_steer_weight)


## One line for the HUD: the keys, what each ability costs, and which one is running right now.
func get_status_text() -> String:
	var dodge: String = "AKTIV" if flock.is_dodging() else "%d Mut" % roundi(dodge_cost)
	var attack: String = "AKTIV" if flock.is_attacking() else "%d Mut" % roundi(attack_cost)
	return "[Leertaste] Ausweichen: %s        [Linksklick] Angriff: %s" % [dodge, attack]
