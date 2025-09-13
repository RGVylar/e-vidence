extends Control

@onready var header: Label = %Header
@onready var chat_box: VBoxContainer = %ChatBox
@onready var choices_box: VBoxContainer = get_node_or_null("%Choices") as VBoxContainer
@onready var btn_back: Button = %BtnBack

var thread: Array[Dictionary] = []
var cursor: int = 0
const BUBBLE_RATIO := 0.66      # ocupa ~66% del ancho del chat
const BUBBLE_MAX_W := 560.0 
const DEBUG := true
func dbg(msg: String) -> void:
	if DEBUG: print("[CHAT] ", msg)

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

	var case_data: Dictionary = DB.current_case as Dictionary

	var display: String = GameState.current_thread
	for c_v in (case_data.get("contacts", []) as Array):
		var c: Dictionary = c_v as Dictionary
		if c.get("id","") == GameState.current_thread:
			display = c.get("name", display); break
	header.text = "Chat — " + display

	var chats: Dictionary = case_data.get("chats", {}) as Dictionary
	var msgs: Array = chats.get(GameState.current_thread, []) as Array

	dbg("nodes ok? header=%s chat_box=%s choices_box=%s btn_back=%s" % [
		is_instance_valid(header), is_instance_valid(chat_box),
		is_instance_valid(choices_box), is_instance_valid(btn_back)
	])
	dbg("thread=%s, msgs_count=%d" % [GameState.current_thread, msgs.size()])

	dbg("clearing chat_box: had %d children" % chat_box.get_child_count())
	for n in chat_box.get_children(): n.queue_free()

	var idx := 0
	for m_v in msgs:
		var m: Dictionary = m_v as Dictionary
		dbg("render msg[%d]: %s" % [idx, str(m)])
		_add_bubble(m.get("from",""), m.get("text",""))
		idx += 1

	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value

	_dump_layout()  # ← imprime tamaños y children tras pintar

	

func _show_next() -> void:
	if not is_instance_valid(choices_box):
		dbg("choices_box no existe; _show_next abortado"); return
	for n in choices_box.get_children(): n.queue_free()

	if cursor >= thread.size(): return

	var entry: Dictionary = thread[cursor] as Dictionary
	cursor += 1

	# Mensaje normal
	if entry.has("text"):
		_add_bubble(entry.get("from", "npc") as String, entry["text"] as String)
		if cursor < thread.size() and not (thread[cursor] as Dictionary).has("choices"):
			await get_tree().process_frame
			_show_next()
			return

	if entry.has("choices"):
		for c: Dictionary in (entry.get("choices", []) as Array):
			var btn: Button = Button.new()
			btn.text = c.get("text", "") as String
			var req: String = c.get("require_evidence", "") as String
			if req != "":
				btn.disabled = not GameState.has_evidence(req)
				if btn.disabled:
					btn.hint_tooltip = "Requiere evidencia: %s" % req
			btn.pressed.connect(_on_choice_pressed.bind(c))
			choices_box.add_child(btn)

func _on_choice_pressed(choice: Dictionary) -> void:
	choices_box.queue_free_children()
	var next_id: String = choice.get("next", "") as String
	for i in range(thread.size()):
		if (thread[i] as Dictionary).get("id", "") == next_id:
			cursor = i
			break
	_show_next()

func _add_bubble(sender: String, text: String) -> void:
	dbg("make bubble sender='%s' len=%d" % [sender, text.length()])

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if sender == "Yo" else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# --- ancho objetivo de la burbuja (usa el ancho del ScrollContainer) ---
	var avail: float = 0.0
	if chat_box and chat_box.get_parent() is Control:
		avail = (chat_box.get_parent() as Control).size.x
	if avail <= 1.0:
		avail = get_viewport_rect().size.x
	var target_w: float = minf(avail * BUBBLE_RATIO, BUBBLE_MAX_W)
	bubble.custom_minimum_size = Vector2(target_w, 0)

	# Estilo
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.bg_color = Color(0.18, 0.35, 0.18, 0.9) if sender == "Yo" else Color(0.22, 0.22, 0.22, 0.9)
	bubble.add_theme_stylebox_override("panel", sb)

	# --- TEXTO: RichTextLabel que calcula su altura ---
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = false
	lbl.fit_content = true              # <- CLAVE: que su mínimo sea el del contenido
	lbl.scroll_active = false           # no queremos scroll interno
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("default_color", Color.WHITE)
	lbl.text = "%s: %s" % [sender, text]

	bubble.add_child(lbl)
	row.add_child(bubble)
	chat_box.add_child(row)

	# Debug de tamaños
	dbg("row.min=%s bubble.min=%s label.min=%s" % [
		row.get_combined_minimum_size(),
		bubble.get_combined_minimum_size(),
		lbl.get_combined_minimum_size()
	])

func _dump_layout() -> void:
	var sc := chat_box.get_parent() as ScrollContainer
	dbg("sizes -> sc.size=%s chat_box.size=%s chat_box.min=%s" % [
		sc.size if sc else Vector2.ZERO,
		chat_box.size,
		chat_box.get_combined_minimum_size()
	])
	for i in chat_box.get_child_count():
		var row := chat_box.get_child(i)
		if row is HBoxContainer:
			var r := row as HBoxContainer
			dbg("row[%d] size=%s children=%d align=%d" % [i, r.size, r.get_child_count(), r.alignment])
			if r.get_child_count() > 0 and r.get_child(-1) is Panel:
				var p := r.get_child(-1) as Panel
				dbg("  panel.size=%s panel.min=%s" % [p.size, p.get_combined_minimum_size()])

func _target_bubble_width() -> float:
	# intenta usar el ancho del ScrollContainer (padre del ChatBox)
	var avail: float = 0.0
	if chat_box and chat_box.get_parent() is Control:
		avail = (chat_box.get_parent() as Control).size.x
	if avail <= 1.0:
		# fallback (por si aún no se ha hecho layout)
		avail = get_viewport_rect().size.x
	return minf(avail * BUBBLE_RATIO, BUBBLE_MAX_W)

func _set_bubble_width_later(bubble: Control) -> void:
	if not is_instance_valid(bubble): return
	var w := _target_bubble_width()
	bubble.custom_minimum_size.x = w
	dbg("set bubble width -> %.1f" % w)
	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/apps/Messaging.tscn")
