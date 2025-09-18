## Global game state management.
##
## This autoload manages the current game state including variables,
## inventory, case selection, and current conversation thread.
## It provides signals for state changes and evidence management.
extends Node

## Dictionary storing arbitrary game variables and flags
var vars: Dictionary = {}
## Dictionary storing player's evidence inventory indexed by evidence ID
var inventory: Dictionary = {}
## Current case ID being played
var current_case_id := "case_demo_general"
## Current conversation thread/contact ID
var current_thread: String = ""

## Emitted when evidence is added to the inventory
## @param id: String - The ID of the evidence that was added
signal evidence_added(id: String)
## Emitted when a game flag/variable changes
## @param key: String - The variable key that changed
## @param value: Variant - The new value
signal flag_changed(key: String, value: Variant)

## Sets a game flag/variable and emits a change signal.
## @param key: String - The variable key to set
## @param value: Variant - The value to assign
func set_flag(key: String, value: Variant) -> void:
	vars[key] = value
	flag_changed.emit(key, value)

## Adds evidence to the player's inventory.
## Evidence must have an "id" field to be added successfully.
## @param e: Dictionary - Evidence data containing at minimum an "id" field
func add_evidence(e: Dictionary) -> void:
	if not e.has("id"): 
		return
	inventory[e.id] = e
	evidence_added.emit(e.id)

## Checks if the player has a specific evidence in their inventory.
## @param id: String - The evidence ID to check
## @return bool - True if the evidence exists in inventory
func has_evidence(id: String) -> bool:
	return inventory.has(id)
