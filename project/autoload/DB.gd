# si no lo tienes ya
extends Node
# opcional:
# class_name DB

var state: Dictionary = {}
const CASE_DIR := "res://data"  # ajusta a tu ruta real
var current_case: Dictionary = {}

func load_case(case_id: String) -> bool:
	# reemplaza el ternario ?:
	var fname := case_id if case_id.ends_with(".json") else "%s.json" % case_id
	var path := "%s/%s" % [CASE_DIR, fname]

	if not FileAccess.file_exists(path):
		push_error("DB.load_case(): no existe %s" % path)
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DB.load_case(): no se pudo abrir %s" % path)
		return false

	var txt := f.get_as_text()

	# evita Variant inferido
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		push_error("DB.load_case(): JSON inválido en %s" % path)
		return false
	var parsed: Dictionary = parsed_v

	current_case = parsed
	return true
