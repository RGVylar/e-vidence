## Chat interface for conversations with contacts.
##
## This script manages the chat UI, including message bubbles, conversation options,
## evidence presentation, and real-time conversation flow with typing indicators.
## It handles both player and NPC messages with customizable timing and effects.
extends Control

# === NODE REFERENCES ===

## Top bar UI elements
@onready var avatar: TextureRect = get_node_or_null("%Avatar") as TextureRect
@onready var name_lbl: Label     = get_node_or_null("%Name")   as Label   
@onready var header: Label       = get_node_or_null("%Header") as Label   # legacy compatibility
@onready var avatar_wrap: Panel = get_node_or_null("%AvatarWrap") as Panel

## Chat area
@onready var chat_box: VBoxContainer = %ChatBox
@onready var btn_back: Button        = %BtnBack

## Bottom bar controls
@onready var add_btn: Button            = get_node_or_null("%BtnAdd")       as Button
@onready var send_btn: Button           = get_node_or_null("%BtnSend")      as Button
@onready var choice_picker: OptionButton = get_node_or_null("%ChoicePicker") as OptionButton
@onready var _sfx_player: AudioStreamPlayer = %AudioStreamPlayer

# === CONFIGURATION ===

## NPC behavior timing configuration
@export_range(0.0, 3.0, 0.05) var npc_reaction_delay: float = 0.50
@export_range(0.0, 3.0, 0.05) var npc_typing_min: float = 0.30
@export_range(0.0, 6.0, 0.05) var npc_typing_max: float = 1.25
@export_range(0.0, 3.0, 0.05) var npc_between_msgs: float = 0.30
@export_range(0.0, 0.20, 0.005) var typing_per_char: float = 0.02  # seconds per character
@export_range(0.0, 5.0, 0.05) var message_interval: float = 0.3

# === INTERNAL STATE ===

## Tracks if NPC reply sequence is currently running
var _npc_reply_running := false
## Current typing indicator row reference
var _typing_row: HBoxContainer = null
## Cached conversation options
var _opts_cache: Array = []

# === CONSTANTS ===

const PATH_MESSAGING := "res://scenes/apps/Messaging.tscn"
const BUBBLE_MIN_H: float = 110.0
const BUBBLE_RATIO: float = 0.86   # % of available width
const BUBBLE_MAX_W: float = 820.0  # maximum width

## Debug logging configuration
const DEBUG := true

## Debug logging helper function.
## @param m: String - Message to log
func dbg(m: String) -> void: if DEBUG: print("[CHAT] ", m)
## === INITIALIZATION ===

func _ready() -> void:
	# señales seguras
	if btn_back:     btn_back.pressed.connect(_on_back_pressed)
	if add_btn:      add_btn.pressed.connect(_on_add_pressed)
	if send_btn:     send_btn.pressed.connect(_on_send_pressed)
	
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		add_child(_sfx_player)

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
	if header:   header.text   = display
	if avatar and avatar_path != "":
		var tex := load(avatar_path)
		if tex is Texture2D:
			avatar.texture = tex
			_make_avatar_round()
		avatar.gui_input.connect(_on_avatar_gui_input)

	if avatar_wrap:
		avatar_wrap.custom_minimum_size = Vector2(40, 40)
		avatar_wrap.clip_contents = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0,0,0,0)
		avatar_wrap.add_theme_stylebox_override("panel", sb)
		
	if is_instance_valid(avatar_wrap) and is_instance_valid(avatar):
		avatar_wrap.custom_minimum_size = Vector2(64, 64)
		avatar_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		avatar_wrap.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		avatar_wrap.size_flags_stretch_ratio = 1.0
		avatar_wrap.clip_contents = true

		# rellenar por completo el wrap
		avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		avatar.expand = true
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# mascara circular
	_make_avatar_round()
	DB.facts_changed.connect(func(_k): _refresh_replies())

	# --- quick replies ---
	if choice_picker:
		dbg("after fill: items=%d sel=%d" % [choice_picker.item_count, choice_picker.get_selected()])
		_fill_replies(GameState.current_thread, DB.current_case as Dictionary)
	
	# --- pinta el hilo ---
	var chats: Dictionary = case_data.get("chats", {}) as Dictionary
	var entry: Variant = chats.get(contact_id)
	var history: Array = []
	if typeof(entry) == TYPE_ARRAY:
		history = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		history = (entry as Dictionary).get("history", []) as Array

	for n in chat_box.get_children(): n.queue_free()
	
	call_deferred("_start_history_render", history)
	
	chat_box.add_theme_constant_override("separation", 12)

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

## Creates and adds a message bubble to the chat.
## @param sender: String - The sender name ("Yo" for player)
## @param text: String - The message text
## @param ts: int - Unix timestamp (0 to hide timestamp)
func _add_bubble(sender: String, text: String, ts: int = 0) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if sender == "Yo" else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bubble.custom_minimum_size = Vector2(_target_bubble_width(), BUBBLE_MIN_H)

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.bg_color = Color(0.18,0.35,0.18,0.95) if sender == "Yo" else Color(0.22,0.22,0.22,0.95)
	bubble.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Texto
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = false
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("default_color", Color.WHITE)
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", 30)
	lbl.add_theme_constant_override("line_separation", 8)
	col.add_child(lbl)

	# Hora
	if ts > 0:
		var time_lbl := Label.new()
		time_lbl.add_theme_font_size_override("font_size", 18)
		time_lbl.modulate = Color(1,1,1,0.7)
		time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var pill := PanelContainer.new()
		var sd := StyleBoxFlat.new()
		sd.bg_color = Color(1,1,1,0.10)
		sd.content_margin_left = 8
		sd.content_margin_right = 8
		sd.content_margin_top = 2
		sd.content_margin_bottom = 2
		sd.corner_radius_top_left = 8
		sd.corner_radius_top_right = 8
		sd.corner_radius_bottom_left = 8
		sd.corner_radius_bottom_right = 8
		pill.add_theme_stylebox_override("panel", sd)
		pill.add_child(time_lbl)

		var meta := HBoxContainer.new()
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_theme_constant_override("separation", 6)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_child(spacer)   # empuja a la derecha
		meta.add_child(pill)
		col.add_child(meta)

		var dt := Time.get_datetime_dict_from_unix_time(ts)
		time_lbl.text = "%02d:%02d" % [dt.hour, dt.minute]
		col.add_child(time_lbl)

	bubble.add_child(col)
	row.add_child(bubble)
	chat_box.add_child(row)
	
	# Play sound effect when message appears
	_play_message_sfx()

## === EVENT HANDLERS ===

## Handles the evidence presentation button press.
## Shows a popup menu with available evidence for the current contact.
func _on_add_pressed() -> void:
	dbg("add pressed (present evidence)")
	var contact_id := GameState.current_thread
	var presentables := _get_presentable_evidence(contact_id)
	
	if presentables.is_empty():
		_show_no_evidence_message()
		return
	
	_show_evidence_selection_menu(presentables, contact_id)

## Gets the list of evidence that can be presented to a contact.
## @param contact_id: String - The contact identifier
## @return Array - Array of presentable evidence dictionaries
func _get_presentable_evidence(contact_id: String) -> Array:
	var presentables: Array = []
	if DB.has_method("get_presentable_evidence"):
		presentables = DB.get_presentable_evidence(contact_id)
	return presentables

## Shows a message when no evidence is available to present.
func _show_no_evidence_message() -> void:
	var ts := Time.get_unix_time_from_system()
	_add_bubble("Yo", "No tengo pruebas útiles ahora.", ts)
	push_msg(GameState.current_thread, "Yo", "No tengo pruebas útiles ahora.") 
	_scroll_to_bottom()

## Creates and shows the evidence selection popup menu.
## @param presentables: Array - Available evidence to present
## @param contact_id: String - The contact identifier
func _show_evidence_selection_menu(presentables: Array, contact_id: String) -> void:
	var pm := _create_evidence_menu(presentables)
	_connect_evidence_menu_selection(pm, contact_id)
	_position_and_show_menu(pm)

## Creates the evidence selection popup menu.
## @param presentables: Array - Available evidence to present
## @return PopupMenu - The configured popup menu
func _create_evidence_menu(presentables: Array) -> PopupMenu:
	var pm := PopupMenu.new()
	pm.name = "_EvidenceMenu"
	pm.add_theme_font_size_override("font_size", 32)
	pm.add_theme_constant_override("v_separation", 8)
	add_child(pm)

	for ev_v in presentables:
		var ev := ev_v as Dictionary
		var idx := pm.item_count
		pm.add_item(String(ev.get("name","(sin nombre)")))
		pm.set_item_metadata(idx, String(ev.get("id","")))
	
	return pm

## Connects the evidence menu selection handler.
## @param pm: PopupMenu - The popup menu to connect
## @param contact_id: String - The contact identifier
func _connect_evidence_menu_selection(pm: PopupMenu, contact_id: String) -> void:
	pm.index_pressed.connect(func(ix: int) -> void:
		var evid_id := String(pm.get_item_metadata(ix))
		_handle_evidence_selection(contact_id, evid_id)
		pm.queue_free()
	)

## Handles the selection of evidence from the menu.
## @param contact_id: String - The contact identifier
## @param evid_id: String - The selected evidence ID
func _handle_evidence_selection(contact_id: String, evid_id: String) -> void:
	dbg("present evidence selected: %s" % evid_id)
	if not DB.has_method("apply_evidence"):
		return
		
	var res := DB.apply_evidence(contact_id, evid_id)
	if res.is_empty():
		return
		
	# Add player message
	var ts := Time.get_unix_time_from_system()
	var player_text := String(res.get("player_text","Presento prueba."))
	_add_bubble("Yo", player_text, ts)
	push_msg(contact_id, "Yo", player_text)
	
	# Process NPC response with timing
	await _process_npc_response(contact_id, res.get("npc_reply", []) as Array)
	
	_refresh_replies()  # Refresh options in case new ones are unlocked
	_scroll_to_bottom()

## Processes NPC response with appropriate timing and effects.
## @param contact_id: String - The contact identifier  
## @param npc_reply: Array - Array of NPC reply messages
func _process_npc_response(contact_id: String, npc_reply: Array) -> void:
	var timing := DB.get_contact_timing(contact_id)
	var reaction := DB.dict_get_number(timing, "npc_reaction_delay", npc_reaction_delay)
	var typ_min  := DB.dict_get_number(timing, "npc_typing_min", npc_typing_min)
	var typ_max  := DB.dict_get_number(timing, "npc_typing_max", npc_typing_max)
	var between  := DB.dict_get_number(timing, "npc_between_msgs", npc_between_msgs)
	var tpc      := DB.dict_get_number(timing, "typing_per_char", typing_per_char)

	# Small delay before NPC reacts
	if reaction > 0.0:
		await get_tree().create_timer(reaction).timeout

	# Play NPC reply sequence
	await _play_npc_reply_sequence(
		npc_reply,
		(name_lbl.text if name_lbl else "NPC"),
		typ_min, typ_max, tpc, between,
		contact_id      
	)

## Positions and shows the evidence menu below the Add button.
## @param pm: PopupMenu - The popup menu to position and show
func _position_and_show_menu(pm: PopupMenu) -> void:
	var gpos := add_btn.get_global_position() if is_instance_valid(add_btn) else Vector2.ZERO
	pm.position = gpos + Vector2(0, add_btn.size.y)
	pm.popup()


## Handles the send button press for conversation options.
## Processes the selected conversation option and triggers NPC responses.
func _on_send_pressed() -> void:
	dbg("send pressed")
	
	if not _validate_choice_picker():
		return
		
	var selected_index := choice_picker.get_selected()
	if not _is_valid_selection(selected_index):
		return
	
	var text := choice_picker.get_item_text(selected_index)
	dbg("selected text='%s'" % text)
	
	# Try new system with options/facts first
	if _try_apply_option(selected_index, text):
		return
		
	# Fallback to old system (plain text)
	_send_plain_text_message(text)

## Validates that the choice picker is ready for use.
## @return bool - True if choice picker is valid and has items
func _validate_choice_picker() -> bool:
	if not is_instance_valid(choice_picker):
		dbg("choice_picker INVALID")
		return false
		
	if choice_picker.item_count == 0:
		dbg("no items → abort")
		return false
		
	return true

## Checks if the selected index is valid.
## @param selected_index: int - The selected index to validate
## @return bool - True if selection is valid
func _is_valid_selection(selected_index: int) -> bool:
	if selected_index < 0:
		dbg("selected = -1 → selecciono 0 por seguridad")
		return false
	return true

## Tries to apply a conversation option using the new system.
## @param index: int - The selected option index
## @param text: String - The option text
## @return bool - True if option was successfully applied
func _try_apply_option(index: int, text: String) -> bool:
	if not DB.has_method("apply_option"):
		return false
		
	var meta: Variant = choice_picker.get_item_metadata(index)
	dbg("metadata type_id=%d value=%s" % [typeof(meta), str(meta)])
	
	var opt_id: String = String(meta)
	if opt_id == "":
		dbg("opt_id vacío → paso a fallback")
		return false
		
	var result := DB.apply_option(GameState.current_thread, opt_id)
	dbg("apply_option('%s') -> empty=%s" % [opt_id, str(result.is_empty())])
	
	if result.is_empty():
		return false
		
	# Process successful option selection
	await _process_option_result(result, text)
	return true

## Processes the result of a successful option application.
## @param result: Dictionary - The result from DB.apply_option
## @param fallback_text: String - Fallback text if result doesn't have player_text
func _process_option_result(result: Dictionary, fallback_text: String) -> void:
	var ts := Time.get_unix_time_from_system()
	var player_text := String(result.get("player_text", fallback_text))
	_add_bubble("Yo", player_text, ts)
	push_msg(GameState.current_thread, "Yo", player_text)
	
	# Process NPC response with timing (reuse existing logic)
	await _process_npc_response(GameState.current_thread, result.get("npc_reply", []) as Array)
	
	_refresh_replies()
	_scroll_to_bottom()

## Sends a plain text message using the fallback system.
## @param text: String - The message text to send
func _send_plain_text_message(text: String) -> void:
	if text.strip_edges() == "":
		return
		
	var ts := Time.get_unix_time_from_system()
	_add_bubble("Yo", text, ts)
	push_msg(GameState.current_thread, "Yo", text)
	_scroll_to_bottom()
	
## Populates the conversation options in the choice picker.
## @param contact_id: String - The contact identifier
## @param case_data: Dictionary - The current case data
func _fill_replies(contact_id: String, case_data: Dictionary) -> void:
	if not is_instance_valid(choice_picker):
		push_error("[CHAT] %ChoicePicker no encontrado"); return

	choice_picker.clear()
	_opts_cache.clear()
	
	# — Reaplica overrides SIEMPRE —
	choice_picker.add_theme_font_size_override("font_size", 32)
	var pm := choice_picker.get_popup()
	pm.add_theme_font_size_override("font_size", 32)
	pm.add_theme_constant_override("v_separation", 8)
	pm.add_theme_constant_override("item_start_padding", 16)
	pm.add_theme_constant_override("item_end_padding", 16)
	pm.reset_size()
	
	dbg("fill_replies(contact=%s)" % contact_id)
	dbg("DB.has_method(get_available_options) = %s" % str(DB.has_method("get_available_options")))

	# Si existen helpers nuevos en DB, úsalo (desbloqueos por facts)
	if "get_available_options" in DB:
		var opts: Array = DB.get_available_options(contact_id)
		dbg("available options: %d" % opts.size())
		for opt_v in opts:
			var opt := opt_v as Dictionary
			var text := String(opt.get("text",""))
			var oid  := String(opt.get("id",""))
			var idx := choice_picker.item_count
			choice_picker.add_item(text)
			choice_picker.set_item_metadata(idx, oid)  # guardamos el id
			_opts_cache.append(opt)
			dbg("  + opt[%d]: id=%s text=%s" % [idx, oid, text])
		if choice_picker.item_count > 0:
			choice_picker.select(0)
			dbg("select(0) => %s" % choice_picker.get_item_text(0))
		return

	# Fallback compatible con tu JSON antiguo: replies[contact_id] = ["...", "..."]
	var replies: Dictionary = case_data.get("replies", {}) as Dictionary
	if replies.has(contact_id):
		var arr: Array = replies[contact_id] as Array
		dbg("legacy replies count: %d" % arr.size())
		for v in (replies[contact_id] as Array):
			choice_picker.add_item(str(v))
		if choice_picker.item_count > 0:
			choice_picker.select(0)
			dbg("select(0) => %s" % choice_picker.get_item_text(0))
	else:
		dbg("no replies for contact (legacy) → añado placeholder")
		choice_picker.add_item("…")
		choice_picker.select(0)


func _make_avatar_round() -> void:
	if not is_instance_valid(avatar): return

	# máscara circular
	var sh := Shader.new()
	sh.code = """
	shader_type canvas_item;
	void fragment() {
		vec2 c = vec2(0.5, 0.5);
		float r = 0.5;
		vec4 col = texture(TEXTURE, UV) * COLOR;
		if (distance(UV, c) > r) discard;
		COLOR = col;
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	avatar.material = mat

	# que el TextureRect RELLENE su rect y centre la imagen
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.custom_minimum_size = Vector2.ZERO

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(PATH_MESSAGING)

## Handles avatar input events for preview functionality.
## @param e: InputEvent - The input event to process
func _on_avatar_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_show_avatar_preview()

## Shows the contact's avatar in a fullscreen lightbox preview.
func _show_avatar_preview() -> void:
	if not is_instance_valid(avatar) or avatar.texture == null:
		return
	# Use the centralized lightbox functionality
	UIHelpers.show_lightbox(avatar.texture)

## === CHAT MANAGEMENT FUNCTIONS ===

## Refreshes the conversation options for the current contact.
func _refresh_replies() -> void:
	_fill_replies(GameState.current_thread, DB.current_case as Dictionary)

## Scrolls the chat to the bottom to show the latest messages.
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer 
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value

## Renders message history sequentially with timing between messages.
## @param history: Array - Array of message dictionaries to render
func _render_history_sequential(history: Array) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)

	for m_v in history:
		var m: Dictionary = m_v as Dictionary
		var from: String = String(m.get("from",""))
		var ts: int = int(m.get("ts", 0))

		if m.has("image"):
			_add_image_bubble(from, String(m["image"]), String(m.get("text","")), ts)
		else:
			_add_bubble(from, String(m.get("text","")), ts)

		await get_tree().create_timer(0.01).timeout
		await get_tree().process_frame
		_scroll_to_bottom()
		if message_interval > 0.0:
			t.start(message_interval)
			await t.timeout

## Plays a message sound effect if available.
func _play_message_sfx() -> void:
	if not is_instance_valid(_sfx_player) or _sfx_player.stream == null:
		return
	_sfx_player.play()

## Starts rendering the conversation history with proper timing.
## @param history: Array - Message history to render
func _start_history_render(history: Array) -> void:
	await get_tree().process_frame  # cede 1 frame una vez
	await _render_history_sequential(history)

func _typing_start(sender_name: String) -> void:
	_typing_end() # limpia por si acaso
	_typing_row = HBoxContainer.new()
	_typing_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_typing_row.alignment = BoxContainer.ALIGNMENT_BEGIN

	var bubble := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.bg_color = Color(0.22,0.22,0.22,0.95)
	bubble.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = "···"
	lbl.add_theme_font_size_override("font_size", 28)
	bubble.add_child(lbl)

	_typing_row.add_child(bubble)
	chat_box.add_child(_typing_row)
	_scroll_to_bottom()

func _typing_end() -> void:
	if is_instance_valid(_typing_row):
		_typing_row.queue_free()
	_typing_row = null

func _npc_typing_duration_for(text: String) -> float:
	# Duración simple por longitud (¡ajústalo a tu gusto!)
	var base := 0.02 * float(text.length()) # 20 ms por carácter
	return clamp(base, npc_typing_min, npc_typing_max)

# Secuencia de respuestas del NPC (con "escribiendo..." + pausas)
func _play_npc_reply_sequence(
	lines: Array,
	npc_name: String,
	typ_min: float, typ_max: float,
	tpc: float,                         # typing_per_char (seg/char)
	between_default: float,
	contact_id: String 
) -> void:
	if _npc_reply_running:
		while _npc_reply_running:
			await get_tree().process_frame
	_npc_reply_running = true

	for line_v in lines:
		var text := ""
		var local_min := typ_min
		var local_max := typ_max
		var local_between := between_default
		var image_path := ""

		# Línea puede ser string o dict con overrides
		if typeof(line_v) == TYPE_DICTIONARY:
			var ld := line_v as Dictionary
			text = String(ld.get("text",""))
			if ld.has("typing_min"):  local_min     = float(ld["typing_min"])
			if ld.has("typing_max"):  local_max     = float(ld["typing_max"])
			if ld.has("between"):     local_between = float(ld["between"])
			if ld.has("after_delay"): local_between = float(ld["after_delay"]) # alias
			if ld.has("image"):       image_path = String(ld["image"]) 
			if ld.has("reaction_delay"):
				await get_tree().create_timer(float(ld["reaction_delay"])).timeout
		else:
			text = String(line_v)
			image_path = ""  # por si acaso

		# “<NPC> está escribiendo…”
		_typing_start(npc_name)
		var dur: float = clamp(tpc * float(text.length()), local_min, local_max)
		if dur > 0.0:
			await get_tree().create_timer(dur).timeout
		_typing_end()
		var ts := Time.get_unix_time_from_system()
		if image_path != "":
			_add_image_bubble(npc_name, image_path, text, ts)  # si hay imagen, la mostramos; text va como caption opcional
			push_msg(contact_id, npc_name, text)
		else:
			_add_bubble(npc_name, text, ts)
			push_msg(contact_id, npc_name, text)

		_scroll_to_bottom()

		if local_between > 0.0:
			await get_tree().create_timer(local_between).timeout

	_npc_reply_running = false

## === IMAGE BUBBLE FUNCTIONS ===

## Creates and adds an image message bubble to the chat.
## @param sender: String - The sender name
## @param image_path: String - Path to the image resource
## @param caption: String - Optional caption text
## @param ts: int - Unix timestamp (0 to hide timestamp)
func _add_image_bubble(sender: String, image_path: String, caption: String = "", ts: int = 0) -> void:
	var tex: Texture2D = load(image_path) as Texture2D
	if tex == null:
		# fallback si no carga la imagen
		_add_bubble(sender, "[imagen no encontrada] " + image_path, ts)
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END if sender == "Yo" else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.bg_color = Color(0.18,0.35,0.18,0.95) if sender == "Yo" else Color(0.22,0.22,0.22,0.95)
	bubble.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var img := TextureRect.new()
	img.texture = tex
	img.expand = true
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(minf(_target_bubble_width(), 640), 360)  # tamaño cómodo
	img.mouse_filter = Control.MOUSE_FILTER_PASS
	# Click to zoom using centralized lightbox
	img.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			UIHelpers.show_lightbox(tex)
	)

	v.add_child(img)

	if caption.strip_edges() != "":
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = false
		lbl.fit_content = true
		lbl.scroll_active = false
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("default_color", Color.WHITE)
		lbl.text = caption
		lbl.add_theme_font_size_override("normal_font_size", 26)
		lbl.add_theme_constant_override("line_separation", 6)
		v.add_child(lbl)

	if ts > 0:
		var time_lbl := Label.new()
		time_lbl.add_theme_font_size_override("font_size", 18)
		time_lbl.modulate = Color(1,1,1,0.7)
		time_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var pill := PanelContainer.new()
		var sd := StyleBoxFlat.new()
		sd.bg_color = Color(1,1,1,0.10)
		sd.content_margin_left = 8
		sd.content_margin_right = 8
		sd.content_margin_top = 2
		sd.content_margin_bottom = 2
		sd.corner_radius_top_left = 8
		sd.corner_radius_top_right = 8
		sd.corner_radius_bottom_left = 8
		sd.corner_radius_bottom_right = 8
		pill.add_theme_stylebox_override("panel", sd)
		pill.add_child(time_lbl)

		var meta := HBoxContainer.new()
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_theme_constant_override("separation", 6)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta.add_child(spacer)
		meta.add_child(pill)
		v.add_child(meta)

		var dt := Time.get_datetime_dict_from_unix_time(ts)
		time_lbl.text = "%02d:%02d" % [dt.hour, dt.minute]
		v.add_child(time_lbl)

	bubble.add_child(v)
	row.add_child(bubble)
	chat_box.add_child(row)

	_play_message_sfx()

func push_msg(contact_id: String, from: String, text: String, ts: int = -1) -> void:
	var chats := (DB.current_case as Dictionary).get("chats", {}) as Dictionary
	var entry: Variant = chats.get(contact_id)
	var history: Array = []
	if ts <= 0:
		ts = Time.get_unix_time_from_system()
	if typeof(entry) == TYPE_ARRAY:
		history = entry as Array
	elif typeof(entry) == TYPE_DICTIONARY:
		history = (entry as Dictionary).get("history", []) as Array

	var msg := {
		"from": from,
		"text": text,
		"ts": ts
	}
	history.append(msg)

	if typeof(entry) == TYPE_ARRAY:
		chats[contact_id] = history
	else:
		(entry as Dictionary)["history"] = history
		chats[contact_id] = entry

	# persiste si guardas estado fuera del caso
	DB.emit_signal("facts_changed", "chat_"+contact_id)
