class_name PlayerAbilities
extends Node

## The swarm's two special abilities. Both are paid from the flock's courage pool (see the HUD).
##
## Dodge ("ability_dodge", Space): the whole swarm dashes in the mouse direction at higher speed,
##     hunters can't catch any boid while it lasts. Costs dodge_cost once.
## Attack ("ability_attack", hold the left mouse button): the whole swarm lunges at the nearest hunter,
##     flies faster and turns much sharper. Every boid touching a hunter throws it back and costs it a life
##     instead of dying itself, and the camera shakes on every hit. Costs courage every second while held;
##     releasing the button (or running out of courage) ends it at once and the swarm regroups.

# flock that uses the abilities
@export var flock: Flock
# flock that the attack goes for (the hunters)
@export var enemy_flock: Flock

@export_group("Dodge")
@export var dodge_cost: float = 10.0
# seconds the dodge lasts
@export var dodge_duration: float = 0.6
@export var dodge_speed_multiplier: float = 2.0

@export_group("Attack")
# courage needed to start the attack at all
@export var attack_start_cost: float = 5.0
# courage paid per second while the button is held
@export var attack_cost_per_second: float = 12.0
# how far (in pixels) from the swarm's center a hunter may be to become the target
@export var attack_range: float = 500.0
@export var attack_speed_multiplier: float = 1.7
# max_steer_force is multiplied by this during the attack, so the swarm turns sharply onto its target
@export var attack_steer_multiplier: float = 3.0
# how strongly the boids fly at their target during the attack
@export var attack_steer_weight: float = 4.0

@export_group("Regroup after attack")
# seconds the swarm is pulled together after the attack ends
@export var regroup_duration: float = 1.5
# flock_pull_weight is multiplied by this while regrouping
@export var regroup_pull_multiplier: float = 6.0


func _unhandled_input(event: InputEvent) -> void:
	# Both actions are defined in Project Settings > Input Map
	if event.is_action_pressed("ability_dodge"):
		try_dodge()
	elif event.is_action_pressed("ability_attack"):
		try_attack()


func _physics_process(delta: float) -> void:
	if not flock.is_attacking():
		return
	# Ends the attack as soon as the button is released or the courage runs out.
	# Checked every step (instead of waiting for a release event) so it also ends if the release
	# happened over the settings panel, which swallows the event.
	if not Input.is_action_pressed("ability_attack") or not flock.spend_courage(attack_cost_per_second * delta):
		flock.stop_attack(regroup_duration, regroup_pull_multiplier)


## Starts the dodge if it isn't running already and the swarm has enough courage.
func try_dodge() -> void:
	if flock.is_dodging() or not flock.spend_courage(dodge_cost):
		return
	flock.start_dodge(dodge_duration, dodge_speed_multiplier)


## Starts the attack if it isn't running already and the swarm has enough courage.
func try_attack() -> void:
	if flock.is_attacking() or not flock.spend_courage(attack_start_cost):
		return
	flock.start_attack(enemy_flock, attack_range, attack_speed_multiplier, attack_steer_multiplier, attack_steer_weight)


## One line for the HUD: the keys, what each ability costs, and which one is running right now.
func get_status_text() -> String:
	var dodge: String = "ACTIVE" if flock.is_dodging() else "%d courage" % roundi(dodge_cost)
	var attack: String = "ACTIVE" if flock.is_attacking() else "%d courage/s" % roundi(attack_cost_per_second)
	return "[Space] Dodge: %s        [Hold left click] Attack: %s" % [dodge, attack]
