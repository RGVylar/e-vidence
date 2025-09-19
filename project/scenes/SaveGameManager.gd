extends Control

@onready var save_list: VBoxContainer = %SaveList
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_exit: Button = %BtnExit
@onready var new_game_dialog: AcceptDialog = %NewGameDialog
@onready var name_input: LineEdit = %NameInput
@onready var btn_create: Button = %BtnCreate
@onready var btn_cancel: Button = %BtnCancel
@onready var delete_confirmation: ConfirmationDialog = %DeleteConfirmation

var save_to_delete: String = ""

func _ready() -> void:
	# Ensure SaveGame is initialized
	SaveGame._ready()
	
	# Connect buttons
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	btn_create.pressed.connect(_on_create_pressed)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	delete_confirmation.confirmed.connect(_on_delete_confirmed)
	
	# Connect SaveGame signals
	SaveGame.save_list_changed.connect(_refresh_save_list)
	
	# Connect name input for Enter key
	name_input.text_submitted.connect(_on_name_submitted)
	
	# Initial refresh
	_refresh_save_list()

func _refresh_save_list() -> void:
	# Clear existing save buttons
	for child in save_list.get_children():
		child.queue_free()
	
	var saves = SaveGame.get_save_list()
	
	if saves.is_empty():
		var no_saves_label = Label.new()
		no_saves_label.text = "No hay partidas guardadas"
		no_saves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_saves_label.add_theme_font_size_override("font_size", 24)
		save_list.add_child(no_saves_label)
		return
	
	for save_data in saves:
		_create_save_entry(save_data)

func _create_save_entry(save_data: Dictionary) -> void:
	var container = HBoxContainer.new()
	container.custom_minimum_size.y = 80
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_BEGIN  # opcional

	
	# Save info container
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Player name
	var name_label = Label.new()
	name_label.text = save_data.get("player_name", "Sin nombre")
	name_label.add_theme_font_size_override("font_size", 24)
	info_container.add_child(name_label)
	
	# Save details
	var details_label = Label.new()
	var created_date = save_data.get("created_date", "")
	var last_saved = save_data.get("last_saved", "")
	var current_case = save_data.get("current_case", "")
	
	var details_text = "Creado: %s" % created_date
	if not last_saved.is_empty() and last_saved != created_date:
		details_text += " | Última partida: %s" % last_saved
	if not current_case.is_empty():
		details_text += " | Caso: %s" % current_case
	
	details_label.text = details_text
	details_label.add_theme_font_size_override("font_size", 16)
	details_label.modulate = Color(0.8, 0.8, 0.8)
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # por si se alarga
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var lines: Array[String] = []
	if not created_date.is_empty():
		lines.append("Creado: %s" % created_date)
	if not last_saved.is_empty() and last_saved != created_date:
		lines.append("Última partida: %s" % last_saved)
	if not current_case.is_empty():
		lines.append("Caso: %s" % current_case)

	details_label.text = "\n".join(lines)
	info_container.add_child(details_label)
	
	container.add_child(info_container)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	buttons_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 12)
	
	# Load button
	var btn_load = Button.new()
	btn_load.text = "Cargar"
	btn_load.custom_minimum_size = Vector2(88, 44)
	btn_load.size_flags_horizontal = 0
	btn_load.pressed.connect(_on_load_save.bind(save_data.get("file_name", "")))
	buttons_container.add_child(btn_load)
	
	# Delete button
	var btn_delete = Button.new()
	btn_delete.text = "Borrar"
	btn_delete.custom_minimum_size = Vector2(88, 44)
	btn_delete.size_flags_horizontal = 0
	btn_delete.modulate = Color(1, 0.5, 0.5)
	btn_delete.pressed.connect(_on_delete_save.bind(save_data.get("file_name", "")))
	buttons_container.add_child(btn_delete)
	
	container.add_child(buttons_container)
	
	# Add separator
	var separator = HSeparator.new()
	separator.custom_minimum_size.y = 2
	
	save_list.add_child(container)
	save_list.add_child(separator)

func _on_new_game_pressed() -> void:
	name_input.text = ""
	new_game_dialog.popup_centered()
	name_input.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_create_pressed() -> void:
	var player_name = name_input.text.strip_edges()
	if player_name.is_empty():
		# Show error feedback
		name_input.placeholder_text = "¡Debes introducir un nombre!"
		name_input.modulate = Color(1, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(name_input, "modulate", Color.WHITE, 1.0)
		tween.tween_callback(func(): name_input.placeholder_text = "Tu nombre...")
		return
	
	var save_id = SaveGame.create_new_save(player_name)
	if not save_id.is_empty():
		new_game_dialog.hide()
		_load_home_scene()
	else:
		# Show error if save creation failed
		name_input.placeholder_text = "Error al crear la partida"
		name_input.modulate = Color(1, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(name_input, "modulate", Color.WHITE, 1.0)
		tween.tween_callback(func(): name_input.placeholder_text = "Tu nombre...")

func _on_cancel_pressed() -> void:
	new_game_dialog.hide()

func _on_name_submitted(text: String) -> void:
	# Allow Enter key to create game
	_on_create_pressed()

func _on_load_save(file_name: String) -> void:
	if SaveGame.load_save(file_name):
		_load_home_scene()
	else:
		# Show error dialog
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "No se pudo cargar la partida. El archivo puede estar corrupto."
		error_dialog.title = "Error al cargar"
		add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(error_dialog.queue_free)
		push_error("Failed to load save: " + file_name)

func _on_delete_save(file_name: String) -> void:
	save_to_delete = file_name
	var save_data = SaveGame.load_save_metadata(file_name)
	var player_name = save_data.get("player_name", "esta partida")
	delete_confirmation.dialog_text = "¿Estás seguro de que quieres borrar la partida de '%s'?" % player_name
	delete_confirmation.popup_centered()

func _on_delete_confirmed() -> void:
	if not save_to_delete.is_empty():
		SaveGame.delete_save(save_to_delete)
		save_to_delete = ""

func _load_home_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
