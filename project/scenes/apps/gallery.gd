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
		show_lightbox(node.texture)

# --- Lightbox simple, reutiliza el patrón del avatar ---
func show_lightbox(tex: Texture2D) -> void:
	if tex == null:
		return

	var overlay: Control = Control.new()
	overlay.name = "_Lightbox"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var big: TextureRect = TextureRect.new()
	big.texture = tex
	big.expand = true
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big.offset_left = 48
	big.offset_right = -48
	big.offset_top = 48
	big.offset_bottom = -48
	overlay.add_child(big)

	overlay.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE):
			overlay.queue_free()
	)

	var tween: Tween = create_tween()
	overlay.modulate = Color(1,1,1,0)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
