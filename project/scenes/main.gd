extends Control

@onready var btn_start: Button = %BtnStart
@onready var case_select: OptionButton = %CaseSelect

var cases: Array[Dictionary] = []  # [{id, title, path}]

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	case_select.item_selected.connect(_on_case_selected)
	_populate_cases()
	# Preselecciona el caso actual si existe
	for i in cases.size():
		var d: Dictionary = cases[i]
		if (d.get("id", "") as String) == GameState.current_case_id:
			case_select.select(i)
			break

func _populate_cases() -> void:
	cases.clear()
	case_select.clear()
	for d in _scan_cases("res://data"):
		cases.append(d)
		case_select.add_item(d.get("title", d.get("id", "")) as String)

func _scan_cases(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("No se puede abrir: %s" % path)
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var f := FileAccess.open(path + "/" + name, FileAccess.READ)
			if f:
				var text := f.get_as_text()
				var parsed: Variant = JSON.parse_string(text)
				if typeof(parsed) == TYPE_DICTIONARY:
					var data: Dictionary = parsed
					var id: String = data.get("id", name.get_basename()) as String
					var title: String = data.get("title", id) as String
					out.append({"id": id, "title": title, "path": path + "/" + name})
		name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("title", "") as String) < (b.get("title", "") as String))
	return out

func _on_case_selected(index: int) -> void:
	if index >= 0 and index < cases.size():
		var d: Dictionary = cases[index]
		GameState.current_case_id = d.get("id", "") as String

func _on_start_pressed() -> void:
	# Si no se ha tocado el selector pero hay elementos, aplica el primero
	if case_select.selected < 0 and cases.size() > 0:
		_on_case_selected(0)
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
