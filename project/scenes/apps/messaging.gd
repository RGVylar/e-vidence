extends Control

@onready var btn_back: Button    = $MarginContainer/VBoxContainer/TopBar/BtnBack
@onready var list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/List
@onready var search: LineEdit    = $MarginContainer/VBoxContainer/Search
@onready var empty_lbl: Label    = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/Empty")

var _filter: String = ""

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	search.text_changed.connect(_on_search_changed)
	if typeof(DB.current_case) != TYPE_DICTIONARY or (DB.current_case as Dictionary).is_empty():
		DB.load_case(GameState.current_case_id)
	DB.facts_changed.connect(func(_k): list_contacts())
	list_contacts()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

func _on_search_changed(t: String) -> void:
	_filter = t.strip_edges().to_lower()
	list_contacts()

func list_contacts() -> void:
	print(">>> case keys: ", (DB.current_case as Dictionary).keys())
	print(">>> contacts(raw): ", (DB.current_case as Dictionary).get("contacts", []))
	print(">>> chats keys: ", (DB.current_case as Dictionary).get("chats", {}).keys())
	print(">>> filter: '", _filter, "'")
	for n in list.get_children(): n.queue_free()

	var case_data: Dictionary = DB.current_case as Dictionary
	var chats: Dictionary = case_data.get("chats", {}) as Dictionary

	var contacts: Array = []
	var raw: Array = (DB.current_case as Dictionary).get("contacts", []) as Array

	if DB.has_method("get_visible_contacts"):
		var visible: Array = DB.get_visible_contacts()
		contacts = visible if not visible.is_empty() else raw
	else:
		contacts = raw
	# ordenar por última actividad si existe
	contacts.sort_custom(func(a, b):
		var ida := String((a as Dictionary).get("id",""))
		var idb := String((b as Dictionary).get("id",""))
		var ta := _last_ts(chats, ida)
		var tb := _last_ts(chats, idb)
		return ta > tb
	)

	var shown := 0
	for c_v in contacts:
		var c: Dictionary = c_v as Dictionary
		var id: String = c.get("id", "") as String
		var name: String = c.get("name", id) as String
		var avatar_path: String = c.get("avatar", "") as String

		var preview := _last_preview(chats, id)
		if _filter != "" and not (name.to_lower().contains(_filter) or preview.to_lower().contains(_filter)):
			continue

		var item := _make_contact_item(id, name, avatar_path, preview)
		list.add_child(item)
		shown += 1

	if empty_lbl:
		empty_lbl.visible = (shown == 0)
		
	print("Añadidos:", shown)

func _last_ts(chats: Dictionary, id: String) -> int:
	if not chats.has(id): return 0
	var entry: Variant = chats.get(id)
	var arr: Array = []
	if typeof(entry) == TYPE_ARRAY:
		arr = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		arr = (entry as Dictionary).get("history", []) as Array
	if arr.is_empty(): return 0
	var last: Dictionary = arr.back() as Dictionary
	return int(last.get("ts", 0)) # si no hay ts, cae a 0

func _last_preview(chats: Dictionary, id: String) -> String:
	if not chats.has(id): return ""
	var entry: Variant = chats.get(id)
	var arr: Array = []
	if typeof(entry) == TYPE_ARRAY:
		arr = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		arr = (entry as Dictionary).get("history", []) as Array
	if arr.is_empty(): return ""
	var last: Dictionary = arr.back() as Dictionary
	var sender: String = String(last.get("from",""))
	var txt: String    = String(last.get("text",""))
	return ("Tú: " + txt) if sender == "Yo" else txt

func _on_contact_pressed(contact_id: String) -> void:
	GameState.current_thread = contact_id
	get_tree().change_scene_to_file("res://scenes/apps/Chat.tscn")

# ---- item UI (tu código, con mínimos ajustes) ----
func _make_contact_item(contact_id: String, name: String, avatar_path: String, preview: String) -> Button:
	var btn := Button.new()
	btn.flat = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	btn.custom_minimum_size = Vector2(720, 120)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# style
	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(1,1,1,0.02)
	sb_norm.content_margin_left = 12
	sb_norm.content_margin_right = 12
	sb_norm.content_margin_top = 8
	sb_norm.content_margin_bottom = 8
	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(1,1,1,0.06)
	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	sb_press.bg_color = Color(1,1,1,0.10)
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(72, 72)
	avatar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar_wrap)

	var avatar := TextureRect.new()
	avatar.expand = true
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if avatar_path != "":
		var tex := load(avatar_path)
		if tex is Texture2D: avatar.texture = tex
	_round_mask(avatar)
	avatar_wrap.add_child(avatar)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 22)
	col.add_child(name_lbl)

	var prev_lbl := Label.new()
	prev_lbl.text = preview
	prev_lbl.clip_text = true
	prev_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prev_lbl.add_theme_font_size_override("font_size", 16)
	prev_lbl.modulate = Color(1,1,1,0.8)
	col.add_child(prev_lbl)

	btn.pressed.connect(_on_contact_pressed.bind(contact_id))
	return btn

func _round_mask(tr: TextureRect) -> void:
	if tr == null: return
	var sh := Shader.new()
	sh.code = """
	shader_type canvas_item;
	void fragment(){
		vec2 c = vec2(0.5, 0.5);
		float r = 0.5;
		vec4 col = texture(TEXTURE, UV) * COLOR;
		if (distance(UV, c) > r) discard;
		COLOR = col;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	tr.material = mat
