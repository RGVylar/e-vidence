extends Control

# --- Top bar ---
@onready var avatar: TextureRect = get_node_or_null("%Avatar") as TextureRect
@onready var name_lbl: Label     = get_node_or_null("%Name")   as Label   # nuevo
@onready var header: Label       = get_node_or_null("%Header") as Label   # por compat

# --- Chat ---
@onready var chat_box: VBoxContainer = %ChatBox
@onready var btn_back: Button        = %BtnBack

# --- Bottom bar (nuevo) ---
@onready var add_btn: Button            = get_node_or_null("%AddBtn")       as Button
@onready var send_btn: Button           = get_node_or_null("%SendBtn")      as Button
@onready var choice_picker: OptionButton      = get_node_or_null("%ChoicePicker") as Button

const PATH_MESSAGING := "res://scenes/apps/Messaging.tscn"

const BUBBLE_RATIO: float = 0.66   # % del ancho disponible
const BUBBLE_MAX_W: float = 560.0  # tope de ancho

const DEBUG := true
func dbg(m: String) -> void: if DEBUG: print("[CHAT] ", m)

func _ready() -> void:
	# señales seguras
	if btn_back:     btn_back.pressed.connect(_on_back_pressed)
	if add_btn:      add_btn.pressed.connect(_on_add_pressed)
	if send_btn:     send_btn.pressed.connect(_on_send_pressed)

	var case_data: Dictionary = DB.current_case as Dictionary
	var contact_id := GameState.current_thread

	# --- nombre + avatar ---
	var display := contact_id
	var avatar_path := ""
	for c_v in (case_data.get("contacts", []) as Array):
		var c: Dictionary = c_v as Dictionary
		if c.get("id","") == contact_id:
			display = c.get("name", display)
			avatar_path = c.get("avatar", "")
			break
	if name_lbl: name_lbl.text = display
	if header:   header.text   = "Chat — " + display
	if avatar and avatar_path != "":
		var tex := load(avatar_path)
		if tex is Texture2D: avatar.texture = tex

	# --- quick replies ---
	if choice_picker:
		_fill_replies(GameState.current_thread, DB.current_case as Dictionary)

	# --- pinta el hilo ---
	var chats: Dictionary = case_data.get("chats", {}) as Dictionary
	var msgs: Array = chats.get(contact_id, []) as Array

	for n in chat_box.get_children(): n.queue_free()
	var i := 0
	for m_v in msgs:
		var m: Dictionary = m_v as Dictionary
		_add_bubble(m.get("from",""), m.get("text",""))
		i += 1
	dbg("rendered msgs: %d" % i)

	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value

# ---------- UI helpers ----------

func _target_bubble_width() -> float:
	var avail: float = 0.0
	if chat_box and chat_box.get_parent() is Control:
		avail = (chat_box.get_parent() as Control).size.x
	if avail <= 1.0:
		avail = get_viewport_rect().size.x
	return minf(avail * BUBBLE_RATIO, BUBBLE_MAX_W)

func _add_bubble(sender: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if sender == "Yo" else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bubble.custom_minimum_size = Vector2(_target_bubble_width(), 0)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.bg_color = Color(0.18,0.35,0.18,0.95) if sender == "Yo" else Color(0.22,0.22,0.22,0.95)
	bubble.add_theme_stylebox_override("panel", sb)

	# Texto
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = false
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("default_color", Color.WHITE)
	lbl.text = text

	bubble.add_child(lbl)
	row.add_child(bubble)
	chat_box.add_child(row)

# ---------- Bottom bar actions ----------

func _on_add_pressed() -> void:
	# Placeholder: mostrar la primera prueba del inventario
	var ids := GameState.inventory.keys()
	if ids.is_empty():
		_add_bubble("Yo", "No tengo pruebas aún.")
	else:
		_add_bubble("Yo", "Presento la prueba: %s" % str(ids[0]))

	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value

func _on_send_pressed() -> void:
	if not is_instance_valid(choice_picker): return
	if choice_picker.item_count == 0: return
	var i := choice_picker.get_selected()
	if i < 0: return
	var text := choice_picker.get_item_text(i)
	if text.strip_edges() == "": return

	_add_bubble("Yo", text)

	# persistir en el caso en memoria:
	# var chats := DB.current_case["chats"] as Dictionary
	# var arr := chats.get(GameState.current_thread, []) as Array
	# arr.append({"from":"Yo","text":text})
	# chats[GameState.current_thread] = arr

	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value
	
func _fill_replies(contact_id: String, case_data: Dictionary) -> void:
	if not is_instance_valid(choice_picker):
		push_error("[CHAT] %ChoicePicker no encontrado"); return

	choice_picker.clear()

	var replies: Dictionary = case_data.get("replies", {}) as Dictionary
	if not replies.has(contact_id):
		push_error("[CHAT] No hay 'replies' para '%s' en el JSON" % contact_id)
		return

	var opts: Array = replies[contact_id] as Array
	if opts.is_empty():
		push_error("[CHAT] 'replies[%s]' está vacío" % contact_id)
		return

	for v in opts:
		choice_picker.add_item(str(v))

	choice_picker.select(0)  # para que se vea texto
	dbg("replies for %s -> %d (text='%s')" % [contact_id, choice_picker.item_count, choice_picker.text])


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(PATH_MESSAGING)
