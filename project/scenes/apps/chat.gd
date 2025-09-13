extends Control

@onready var header: Label = %Header
@onready var chat_box: VBoxContainer = %ChatBox
@onready var choices_box: VBoxContainer = %Choices
@onready var btn_back: Button = %BtnBack

var thread: Array[Dictionary] = []
var cursor: int = 0

const DEBUG := true
func dbg(msg: String) -> void:
	if DEBUG: print("[CHAT] ", msg)

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	
	print("Chat opened for:", GameState.current_thread)
	var case_data: Dictionary = DB.current_case as Dictionary

	var display: String = GameState.current_thread
	for c_v in (case_data.get("contacts", []) as Array):
		var c: Dictionary = c_v as Dictionary
		if c.get("id", "") == GameState.current_thread:
			display = c.get("name", display)
			break
	header.text = "Chat — " + display

	var chats: Dictionary = case_data.get("chats", {}) as Dictionary
	var msgs: Array = chats.get(GameState.current_thread, []) as Array
	print("msgs for", GameState.current_thread, "=>", msgs)
	
	dbg("nodes ok? header=%s chat_box=%s btn_back=%s" % [
		is_instance_valid(header), is_instance_valid(chat_box), is_instance_valid(btn_back)
	])
	
	dbg("thread=%s, msgs_count=%d" % [GameState.current_thread, msgs.size()])

	for n in chat_box.get_children():
		n.queue_free()
	for m_v in msgs:
		var m: Dictionary = m_v as Dictionary
		print("render msg:", m)
		_add_bubble(m.get("from", ""), m.get("text", ""))
		
	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = sc.get_v_scroll_bar().max_value
	

func _show_next() -> void:
	choices_box.queue_free_children()
	if cursor >= thread.size():
		return

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
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if sender == "Yo" else BoxContainer.ALIGNMENT_BEGIN


	var lbl := RichTextLabel.new()
	lbl.text = "%s: %s" % [sender, text]
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.fit_content = true
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("default_color", Color.WHITE)

	var bubble := Panel.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Estilo (Godot 4 → StyleBoxFlat)
	var sb := StyleBoxFlat.new()
	# radios
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	# márgenes internos
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	# color según emisor
	sb.bg_color = Color(0.18, 0.35, 0.18, 0.9) if sender == "Yo" else Color(0.22, 0.22, 0.22, 0.9)

	bubble.add_theme_stylebox_override("panel", sb)

	var wrap := VBoxContainer.new()
	wrap.add_child(lbl)
	bubble.add_child(wrap)

	row.add_child(bubble)
	chat_box.add_child(row)
	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/apps/Messaging.tscn")
