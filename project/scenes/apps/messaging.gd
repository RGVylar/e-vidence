extends Control

@onready var list: VBoxContainer = %List
@onready var btn_back: Button = %BtnBack

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	if typeof(DB.current_case) != TYPE_DICTIONARY or (DB.current_case as Dictionary).is_empty():
		DB.load_case(GameState.current_case_id)
	list_contacts()

func list_contacts() -> void:
	for n in list.get_children(): n.queue_free()

	var case_data: Dictionary = DB.current_case as Dictionary
	var contacts: Array = case_data.get("contacts", []) as Array
	var chats: Dictionary     = case_data.get("chats", {}) as Dictionary
	print("contacts => ", contacts)

	for c_v in contacts:
		var c: Dictionary = c_v as Dictionary
		var id: String = c.get("id", "") as String
		var name: String = c.get("name", id) as String
		var avatar_path: String = c.get("avatar", "") as String

		# último mensaje como preview
		var preview := ""
		if chats.has(id):
			var arr: Array = chats[id] as Array
			if arr.size() > 0:
				var last: Dictionary = arr.back() as Dictionary
				var sender: String = last.get("from", "") as String
				var txt: String     = last.get("text", "") as String
				preview = ("Tú: " if sender == "Yo" else "") + txt


		var item := _make_contact_item(id, name, avatar_path, preview)
		list.add_child(item)
		print("added item:", name, " (", id, ")")


func _on_contact_pressed(contact_id: String) -> void:
	print("contact pressed:", contact_id)
	GameState.current_thread = contact_id
	print("changing scene to Chat.tscn")
	get_tree().change_scene_to_file("res://scenes//apps//Chat.tscn")

func _pretty_contact(id: String) -> String:
	if id == "friend_1":
		return "Amigo"
	return id.capitalize()

	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes//Home.tscn")

func _make_contact_item(contact_id: String, name: String, avatar_path: String, preview: String) -> Button:
	# Fila clickable
	var btn := Button.new()
	btn.flat = false    
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 250)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(1,1,1,0.02)
	sb_norm.content_margin_left = 8
	sb_norm.content_margin_right = 8
	sb_norm.content_margin_top = 4
	sb_norm.content_margin_bottom = 4

	var sb_hover := sb_norm.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(1,1,1,0.06)

	var sb_press := sb_norm.duplicate() as StyleBoxFlat
	sb_press.bg_color = Color(1,1,1,0.10)

	btn.add_theme_stylebox_override("normal", sb_norm)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_press)

	# Layout interno
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE  
	btn.add_child(row)

	# Avatar redondo (44x44)
	var avatar_wrap := Control.new()
	avatar_wrap.custom_minimum_size = Vector2(190, 190)
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

	# Columna de textos
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 40)
	col.add_child(name_lbl)

	var prev_lbl := Label.new()
	prev_lbl.text = preview
	prev_lbl.modulate = Color(1,1,1,0.8)
	prev_lbl.clip_text = true
	prev_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prev_lbl.add_theme_font_size_override("font_size", 30)
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
		vec2 c=vec2(0.5,0.5);
		float r=0.5;
		vec4 col = texture(TEXTURE, UV)*COLOR;
		if(distance(UV,c)>r) discard;
		COLOR = col;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	tr.material = mat
