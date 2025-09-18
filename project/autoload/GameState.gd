extends Node

var vars: Dictionary = {}
var inventory: Dictionary = {}           # evidencias por id
# var current_case_id := "case_tutorial"
# var current_case_id := "case_improved_dialogues"
#var current_case_id := "case_final_test"
var current_case_id := "case_demo_general"
var current_thread: String = ""   # id del contacto/hilo seleccionado

signal evidence_added(id)
signal flag_changed(key, value)

func set_flag(key: String, value) -> void:
	vars[key] = value
	flag_changed.emit(key, value)

func add_evidence(e: Dictionary) -> void:
	if not e.has("id"): return
	inventory[e.id] = e
	evidence_added.emit(e.id)

func has_evidence(id: String) -> bool:
	return inventory.has(id)
