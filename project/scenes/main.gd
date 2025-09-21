extends Control

@onready var btn_start: Button = %BtnStart
@onready var case_select: OptionButton = %CaseSelect
@onready var btn_options: Button = %BtnOptions

var cases: Array[Dictionary] = []  # [{id, title, path}]
var options_dialog: AcceptDialog

func _ready() -> void:
	# Connect signals
	btn_start.pressed.connect(_on_start_pressed)
	case_select.item_selected.connect(_on_case_selected)
	if btn_options:
		btn_options.pressed.connect(_on_options_pressed)
	
	# Connect to localization changes
	Localization.language_changed.connect(_on_language_changed)
	
	_populate_cases()
	_update_ui_text()
	
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
		push_warning("Cannot open: %s" % path)
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

func _update_ui_text() -> void:
	"""Update UI text with current language"""
	if btn_start:
		btn_start.text = "► " + Localization.tr("new_game", "Start")
	if btn_options:
		btn_options.text = Localization.tr("options", "Options")

func _on_language_changed(new_language: String) -> void:
	"""Called when language changes"""
	_update_ui_text()

func _on_options_pressed() -> void:
	"""Show options dialog with language selection"""
	if options_dialog != null:
		options_dialog.queue_free()
	
	options_dialog = AcceptDialog.new()
	options_dialog.title = Localization.tr("options", "Options")
	options_dialog.size = Vector2(450, 350)
	options_dialog.get_ok_button().text = Localization.tr("close", "Close")
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	# Language selection section
	var lang_section = VBoxContainer.new()
	lang_section.add_theme_constant_override("separation", 8)
	
	# Language selection label
	var lang_label = Label.new()
	lang_label.text = Localization.tr("language_selection", "Language selection") + ":"
	lang_label.add_theme_font_size_override("font_size", 24)
	lang_section.add_child(lang_label)
	
	# Current language display
	var current_lang_label = Label.new()
	var current_display = Localization.get_language_display_name(Localization.get_current_language())
	current_lang_label.text = Localization.tr("current_language", "Current language: %s") % current_display
	current_lang_label.add_theme_font_size_override("font_size", 18)
	current_lang_label.modulate = Color(0.8, 0.8, 0.8)
	lang_section.add_child(current_lang_label)
	
	# Language selection dropdown
	var lang_option = OptionButton.new()
	lang_option.add_theme_font_size_override("font_size", 20)
	lang_option.custom_minimum_size = Vector2(350, 50)
	
	var available_languages = Localization.get_available_languages()
	var current_language = Localization.get_current_language()
	var selected_index = -1
	
	for i in available_languages.size():
		var lang_code = available_languages[i]
		var display_name = Localization.get_language_display_name(lang_code)
		lang_option.add_item(display_name)
		lang_option.set_item_metadata(i, lang_code)
		
		if lang_code == current_language:
			selected_index = i
	
	if selected_index >= 0:
		lang_option.select(selected_index)
	
	lang_option.item_selected.connect(func(index: int):
		var selected_lang = lang_option.get_item_metadata(index) as String
		if selected_lang != Localization.get_current_language():
			Localization.set_language(selected_lang)
			# Update the current language display
			var new_display = Localization.get_language_display_name(selected_lang)
			current_lang_label.text = Localization.tr("current_language", "Current language: %s") % new_display
			# Update dialog title and button
			options_dialog.title = Localization.tr("options", "Options")
			options_dialog.get_ok_button().text = Localization.tr("close", "Close")
			lang_label.text = Localization.tr("language_selection", "Language selection") + ":"
	)
	
	lang_section.add_child(lang_option)
	vbox.add_child(lang_section)
	
	options_dialog.add_child(vbox)
	add_child(options_dialog)
	options_dialog.popup_centered()

func _on_start_pressed() -> void:
	# Si no se ha tocado el selector pero hay elementos, aplica el primero
	if case_select.selected < 0 and cases.size() > 0:
		_on_case_selected(0)
	get_tree().change_scene_to_file("res://scenes/SaveGameManager.tscn")
