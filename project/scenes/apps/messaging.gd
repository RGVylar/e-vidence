extends Control

@onready var btn_back: Button    = $MarginContainer/VBoxContainer/TopBar/BtnBack
@onready var list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/List
@onready var search: LineEdit    = $MarginContainer/VBoxContainer/Search
@onready var empty_lbl: Label    = get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/Empty")

var _filter: String = ""

const MSGAPP_DEBUG := false
func _log(s: String) -> void:
	if MSGAPP_DEBUG: print("[MSGAPP] ", s)

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	search.text_changed.connect(_on_search_changed)
	if typeof(DB.current_case) != TYPE_DICTIONARY or (DB.current_case as Dictionary).is_empty():
		DB.load_case(GameState.current_case_id)
	_ensure_timestamps_for_case()
	DB.facts_changed.connect(func(_k): list_contacts())
	list_contacts()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Home.tscn")

func _on_search_changed(t: String) -> void:
	_filter = t.strip_edges().to_lower()
	list_contacts()

func list_contacts() -> void:
	_log(">>> case keys: " + str((DB.current_case as Dictionary).keys()))
	_log(">>> contacts(raw): " + str((DB.current_case as Dictionary).get("contacts", [])))
	_log(">>> chats keys: " + str((DB.current_case as Dictionary).get("chats", {}).keys()))
	_log(">>> filter: '" + _filter + "'")
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
		
	_log("Añadidos:" + str(shown))

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
	btn.custom_minimum_size = Vector2(0, 156)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# style
	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(1,1,1,0.02)
	sb_norm.content_margin_left = 14
	sb_norm.content_margin_right = 14
	sb_norm.content_margin_top = 10
	sb_norm.content_margin_bottom = 10
	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(1,1,1,0.06)
	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	sb_press.bg_color = Color(1,1,1,0.10)
	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(112, 112)
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
	name_lbl.add_theme_font_size_override("font_size", 32)
	col.add_child(name_lbl)
	
	var prev_lbl := Label.new()
	prev_lbl.text = preview
	prev_lbl.clip_text = true
	prev_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prev_lbl.add_theme_font_size_override("font_size", 22)
	prev_lbl.modulate = Color(1,1,1,0.8)
	col.add_child(prev_lbl)

	# DERECHA: hora + badge
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_SHRINK_END 
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.alignment = VBoxContainer.ALIGNMENT_BEGIN
	right.custom_minimum_size = Vector2(96, 0)
	row.add_child(right)

	var time_lbl := Label.new()
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_lbl.add_theme_font_size_override("font_size", 18)
	time_lbl.modulate = Color(1,1,1,0.75)
	time_lbl.custom_minimum_size = Vector2(64, 0) 
	var last_ts := _last_ts((DB.current_case as Dictionary).get("chats", {}) as Dictionary, contact_id)
	time_lbl.text = _format_time_or_date(last_ts)
	right.add_child(time_lbl)

	var unread := _unread_count(contact_id)
	if unread > 0:
		var badge := Label.new()
		badge.text = str(unread)
		badge.add_theme_font_size_override("font_size", 14)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.6, 1.0, 1.0)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		badge.add_theme_stylebox_override("normal", sb)
		right.add_child(badge)


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

func _format_time(ts:int) -> String:
	if ts <= 0: return ""
	var dt := Time.get_datetime_dict_from_unix_time(ts)
	return "%02d:%02d" % [dt.hour, dt.minute]

func _unread_count(contact_id:String) -> int:
	# Sin sistema de "leídos", marcamos 1 si el último mensaje NO es tuyo.
	var chats := (DB.current_case as Dictionary).get("chats", {}) as Dictionary
	if not chats.has(contact_id): return 0
	var entry = chats.get(contact_id)
	var arr:Array = []
	if typeof(entry) == TYPE_ARRAY:
		arr = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		arr = (entry as Dictionary).get("history", []) as Array
	if arr.is_empty(): return 0
	var last:Dictionary = arr.back() as Dictionary
	return 1 if String(last.get("from","")) != "Yo" else 0

func _last_time_str(contact_id:String) -> String:
	var chats := (DB.current_case as Dictionary).get("chats", {}) as Dictionary
	if not chats.has(contact_id): return ""
	var entry = chats.get(contact_id)
	var arr:Array = []
	if typeof(entry) == TYPE_ARRAY:
		arr = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		arr = (entry as Dictionary).get("history", []) as Array
	if arr.is_empty(): return ""
	var last:Dictionary = arr.back() as Dictionary

	# 1) ts (epoch seconds)
	var ts_v = last.get("ts", null)
	if typeof(ts_v) == TYPE_INT or typeof(ts_v) == TYPE_FLOAT:
		return _format_time(int(ts_v))

	# 2) time string (ej: "14:32" o "14:32:10")
	var tstr := String(last.get("time", ""))
	if tstr != "": 
		# recorta a HH:MM
		var parts := tstr.split(":")
		if parts.size() >= 2:
			return "%02d:%02d" % [int(parts[0]), int(parts[1])]
		return tstr

	return ""

func _ensure_timestamps_for_case() -> void:
	var chats := (DB.current_case as Dictionary).get("chats", {}) as Dictionary
	var base := Time.get_unix_time_from_system() - 60
	for id in chats.keys():
		var entry: Variant = chats.get(id)
		var hist:Array = []
		if typeof(entry) == TYPE_ARRAY:
			hist = entry as Array
		elif typeof(entry) == TYPE_DICTIONARY:
			hist = (entry as Dictionary).get("history", []) as Array
		var t := base
		for i in range(hist.size()):
			var m:Dictionary = hist[i]
			if not m.has("ts"):
				m["ts"] = t
				hist[i] = m
			t += 10
		if typeof(entry) == TYPE_ARRAY:
			chats[id] = hist
		else:
			(entry as Dictionary)["history"] = hist
			chats[id] = entry

func _format_time_or_date(ts:int) -> String:
	if ts <= 0:
		return ""
	var now := Time.get_datetime_dict_from_system()
	var dt  := Time.get_datetime_dict_from_unix_time(ts)

	# mismo día → HH:MM
	if now.year == dt.year and now.month == dt.month and now.day == dt.day:
		return "%02d:%02d" % [dt.hour, dt.minute]

	# otro día → DD/MM
	return "%02d/%02d" % [dt.day, dt.month]
