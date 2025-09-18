## Gallery application for viewing collected evidence images.
##
## This script manages the photo gallery interface, displaying
## images that have been unlocked through game progression.
extends Control

@onready var btn_back: Button    = $MarginContainer/VBoxContainer/TopBar/BtnBack
@onready var grid: GridContainer = $MarginContainer/VBoxContainer/Scroll/GridContainer

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	if typeof(DB.current_case) != TYPE_DICTIONARY or (DB.current_case as Dictionary).is_empty():
		DB.load_case(GameState.current_case_id)
	DB.facts_changed.connect(func(_k): _render_gallery())
	_render_gallery()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

func _render_gallery() -> void:
	# Limpia grid
	for n in grid.get_children():
		n.queue_free()

	# Obtiene items visibles
	var items: Array = []
	if DB.has_method("get_gallery_items"):
		items = DB.get_gallery_items()
	else:
		var arr: Array = (DB.current_case as Dictionary).get("gallery", []) as Array
		for v in arr:
			var item: Dictionary
			if typeof(v) == TYPE_STRING:
				item = {"id": String(v), "path": String(v)}
			else:
				item = v as Dictionary
			items.append(item)


	# Crea miniaturas clicables
	for it_v in items:
		var it: Dictionary = it_v as Dictionary
		var path: String = String(it.get("path",""))
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue

		var thumb: TextureRect = TextureRect.new()
		thumb.texture = tex
		thumb.expand = true
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.custom_minimum_size = Vector2(320, 320)

		# Conecta el click de este thumb a nuestro handler, pasando el propio nodo
		thumb.gui_input.connect(_on_thumb_gui_input.bind(thumb))

		grid.add_child(thumb)

func _on_thumb_gui_input(ev: InputEvent, node: TextureRect) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# Use centralized lightbox functionality
		UIHelpers.show_lightbox(node.texture)
