extends Control

# test github actions

# --- Top bar ---
@onready var avatar: TextureRect = get_node_or_null("%Avatar") as TextureRect
@onready var name_lbl: Label     = get_node_or_null("%Name")   as Label   # nuevo
@onready var header: Label       = get_node_or_null("%Header") as Label   # por compat
@onready var avatar_wrap: Panel = get_node_or_null("%AvatarWrap") as Panel

# --- Chat ---
@onready var chat_box: VBoxContainer = %ChatBox
@onready var btn_back: Button        = %BtnBack

# --- Bottom bar (nuevo) ---
@onready var add_btn: Button            = get_node_or_null("%BtnAdd")       as Button
@onready var send_btn: Button           = get_node_or_null("%BtnSend")      as Button
@onready var choice_picker: OptionButton = get_node_or_null("%ChoicePicker") as OptionButton
@onready var _sfx_player: AudioStreamPlayer = %AudioStreamPlayer

@export_range(0.0, 3.0, 0.05) var npc_reaction_delay: float = 0.50
@export_range(0.0, 3.0, 0.05) var npc_typing_min: float = 0.30
@export_range(0.0, 6.0, 0.05) var npc_typing_max: float = 1.25
@export_range(0.0, 3.0, 0.05) var npc_between_msgs: float = 0.30
@export_range(0.0, 0.20, 0.005) var typing_per_char: float = 0.02  # s por carácter (0.02 = 20 ms)
@export_range(0.0, 5.0, 0.05) var message_interval: float = 0.3

var _npc_reply_running := false
var _typing_row: HBoxContainer = null
var _opts_cache: Array = []

const PATH_MESSAGING := "res://scenes/apps/Messaging.tscn"
const BUBBLE_MIN_H: float = 110.0
const BUBBLE_RATIO: float = 0.86   # % del ancho disponible
const BUBBLE_MAX_W: float = 820.0  # tope de ancho

const CHAT_DEBUG := false
func _log(s: String) -> void:
	if CHAT_DEBUG: print("[CHAT] ", s)

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
		_log("after fill: items=%d sel=%d" % [choice_picker.item_count, choice_picker.get_selected()])
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
	
	# --- sonido al aparecer ---
	_play_message_sfx()

# ---------- Bottom bar actions ----------

func _on_add_pressed() -> void:
	_log("add pressed (present evidence)")
	var contact_id := GameState.current_thread

	# pedir a DB la lista de pruebas presentables ahora
	var presentables: Array = []
	if "get_presentable_evidence" in DB or DB.has_method("get_presentable_evidence"):
		presentables = DB.get_presentable_evidence(contact_id)

	if presentables.is_empty():
		var ts := Time.get_unix_time_from_system()
		_add_bubble("Yo", "No tengo pruebas útiles ahora.", ts)
		push_msg(GameState.current_thread, "Yo", "No tengo pruebas útiles ahora.") 
		_scroll_to_bottom()
		return

	# Popup simple para elegir
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

	pm.index_pressed.connect(func(ix: int) -> void:
		var evid_id := String(pm.get_item_metadata(ix))
		_log("Presentando prueba: %s" % evid_id)
		if DB.has_method("apply_evidence"):
			var res := DB.apply_evidence(contact_id, evid_id)
			if not res.is_empty():
				var ts := Time.get_unix_time_from_system()
				_add_bubble("Yo", String(res.get("player_text","Presento prueba.")), ts)
				push_msg(contact_id, "Yo", String(res.get("player_text","Presento prueba.")))  # ← AÑADE AQUÍ

				var T: Dictionary = DB.get_contact_timing(contact_id)
				var reaction := DB.dict_get_number(T, "npc_reaction_delay", npc_reaction_delay)
				var typ_min  := DB.dict_get_number(T, "npc_typing_min",    npc_typing_min)
				var typ_max  := DB.dict_get_number(T, "npc_typing_max",    npc_typing_max)
				var between  := DB.dict_get_number(T, "npc_between_msgs",  npc_between_msgs)
				var tpc      := DB.dict_get_number(T, "typing_per_char",   typing_per_char)

				# 1) pequeña pausa antes de que el NPC reaccione
				if reaction > 0.0:
					await get_tree().create_timer(reaction).timeout

				# 2) secuenciar las líneas del NPC
				await _play_npc_reply_sequence(
					res.get("npc_reply", []) as Array,
					(name_lbl.text if name_lbl else "NPC"),
					typ_min, typ_max, tpc, between,
					contact_id      
				)

				_refresh_replies()   # por si desbloquea opciones
				_scroll_to_bottom()
		pm.queue_free()
	)

	# abrir bajo el botón Add
	var gpos := add_btn.get_global_position() if is_instance_valid(add_btn) else Vector2.ZERO
	pm.position = gpos + Vector2(0, add_btn.size.y)
	pm.popup()


func _on_send_pressed() -> void:
	_log("send pressed")
	if not is_instance_valid(choice_picker):
		_log("choice_picker INVALID")
		return
	_log("item_count=%d selected=%d" % [choice_picker.item_count, choice_picker.get_selected()])

	if choice_picker.item_count == 0:
		_log("No hay opciones para enviar")
		return

	var i := choice_picker.get_selected()
	if i < 0:
		_log("Selected = -1 → selecciono 0 por seguridad")
		return

	var text := choice_picker.get_item_text(i)
	_log("Selected text='%s'" % text)

	# Sistema nuevo con options/facts
	if DB.has_method("apply_option"):
		var meta: Variant = choice_picker.get_item_metadata(i)	
		_log("metadata type_id=%d value=%s" % [typeof(meta), str(meta)])
		var opt_id: String = String(choice_picker.get_item_metadata(i))
		if opt_id != "":
			var result := DB.apply_option(GameState.current_thread, opt_id)
			_log("apply_option('%s') -> %s" % [opt_id, str(result)])
			if not result.is_empty():
				var ts := Time.get_unix_time_from_system()
				_add_bubble("Yo", String(result.get("player_text", text)), ts)
				push_msg(GameState.current_thread, "Yo", String(result.get("player_text", text)))

				var contact_id := GameState.current_thread
				var T: Dictionary = DB.get_contact_timing(contact_id)

				var reaction := DB.dict_get_number(T, "npc_reaction_delay", npc_reaction_delay)
				var typ_min  := DB.dict_get_number(T, "npc_typing_min",    npc_typing_min)
				var typ_max  := DB.dict_get_number(T, "npc_typing_max",    npc_typing_max)
				var between  := DB.dict_get_number(T, "npc_between_msgs",  npc_between_msgs)
				var tpc      := DB.dict_get_number(T, "typing_per_char",   typing_per_char)

				# 1) pequeña pausa antes de que el NPC reaccione
				if reaction > 0.0:
					await get_tree().create_timer(reaction).timeout

				# 2) secuenciar las líneas del NPC
				await _play_npc_reply_sequence(
					result.get("npc_reply", []) as Array,
					(name_lbl.text if name_lbl else "NPC"),
					typ_min, typ_max, tpc, between,
					contact_id  
				)
				var ok := SaveGame.save_current_game()
				_log("autosave after NPC reply → %s (save_id=%s)" % [str(ok), SaveGame.current_save_id])
				_refresh_replies()
				_scroll_to_bottom()
				return
		else:
			_log("opt_id vacío → paso a fallback")

	# Fallback (modo antiguo solo texto)
	if text.strip_edges() != "":
		var ts := Time.get_unix_time_from_system()
		_add_bubble("Yo", text, ts)
		push_msg(GameState.current_thread, "Yo", text)
		_scroll_to_bottom()
	
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
	
	_log("fill_replies(contact=%s)" % contact_id)
	_log("DB.has_method(get_available_options) = %s" % str(DB.has_method("get_available_options")))

	# Si existen helpers nuevos en DB, úsalo (desbloqueos por facts)
	if "get_available_options" in DB:
		var opts: Array = DB.get_available_options(contact_id)
		_log("available options: %d" % opts.size())
		for opt_v in opts:
			var opt := opt_v as Dictionary
			var text := String(opt.get("text",""))
			var oid  := String(opt.get("id",""))
			var idx := choice_picker.item_count
			choice_picker.add_item(text)
			choice_picker.set_item_metadata(idx, oid)  # guardamos el id
			_opts_cache.append(opt)
			_log("  + opt[%d]: id=%s text=%s" % [idx, oid, text])
		if choice_picker.item_count > 0:
			choice_picker.select(0)
			_log("Opciones cargadas: %d" % choice_picker.item_count)
		return

	# Fallback compatible con tu JSON antiguo: replies[contact_id] = ["...", "..."]
	var replies: Dictionary = case_data.get("replies", {}) as Dictionary
	if replies.has(contact_id):
		var arr: Array = replies[contact_id] as Array
		_log("legacy replies count: %d" % arr.size())
		for v in (replies[contact_id] as Array):
			choice_picker.add_item(str(v))
		if choice_picker.item_count > 0:
			choice_picker.select(0)
			_log("Opciones cargadas: %d" % choice_picker.item_count)
	else:
		_log("No hay opciones para este contacto")
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

func _on_avatar_gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_show_avatar_preview()

func _show_avatar_preview() -> void:
	if not is_instance_valid(avatar) or avatar.texture == null:
		return

	# Overlay a pantalla completa
	var overlay := Control.new()
	overlay.name = "_AvatarLightbox"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Fondo oscurecido
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	# Foto centrada
	var big := TextureRect.new()
	big.texture = avatar.texture
	big.expand = true
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big.offset_left = 48
	big.offset_right = -48
	big.offset_top = 48
	big.offset_bottom = -48
	big.material = null
	overlay.add_child(big)

	# Cerrar: clic/ESC
	overlay.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
		elif ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
			overlay.queue_free()
	)

	# animación de entrada
	var tween := create_tween()
	overlay.modulate = Color(1,1,1,0)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
func _refresh_replies() -> void:
	_fill_replies(GameState.current_thread, DB.current_case as Dictionary)
	
func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	var sc := chat_box.get_parent() as ScrollContainer 
	if sc: sc.scroll_vertical = sc.get_v_scroll_bar().max_value
	
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

func _play_message_sfx() -> void:
	if not is_instance_valid(_sfx_player) or _sfx_player.stream == null:
		return
	_sfx_player.play()

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

# --- Lightbox local para imágenes en chat ---
func _show_image_lightbox(tex: Texture2D) -> void:
	if tex == null:
		return
	var overlay: Control = Control.new()
	overlay.name = "_ImgLightbox"
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

# --- Burbuja de imagen ---
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
	# click para zoom
	img.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_image_lightbox(tex)
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
	_log("push_msg: chats[%s] now has %d messages" % [contact_id, history.size()])
	DB.emit_signal("facts_changed", "chat_"+contact_id)
