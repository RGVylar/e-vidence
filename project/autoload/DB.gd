extends Node

var state: Dictionary = {}
const CASE_DIR := "res://data"
var current_case: Dictionary = {}

signal facts_changed(changed_keys: Array[String])

func load_case(case_id: String) -> bool:
	var fname := case_id if case_id.ends_with(".json") else "%s.json" % case_id
	var path := "%s/%s" % [CASE_DIR, fname]

	if not FileAccess.file_exists(path):
		push_error("DB.load_case(): no existe %s" % path)
		return false

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DB.load_case(): no se pudo abrir %s" % path)
		return false

	var txt := f.get_as_text()

	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		push_error("DB.load_case(): JSON inválido en %s" % path)
		return false
	var parsed: Dictionary = parsed_v

	current_case = parsed_v as Dictionary
	current_case["_id"] = case_id
	var facts_v: Variant = (current_case as Dictionary).get("facts", null)
	if typeof(facts_v) != TYPE_DICTIONARY:
		current_case["facts"] = {}

	return true


func get_facts() -> Dictionary:
	if typeof(current_case) == TYPE_DICTIONARY:
		return (current_case as Dictionary).get("facts", {}) as Dictionary
	return {}

func get_fact(key: String, default_val := false) -> bool:
	var facts := get_facts()
	return bool(facts.get(key, default_val))

func set_fact(key: String, value: bool = true) -> void:
	if typeof(current_case) != TYPE_DICTIONARY:
		return
	var case_dict := current_case as Dictionary
	var facts: Dictionary = case_dict.get("facts", {}) as Dictionary
	var prev: bool = bool(facts.get(key, false))
	facts[key] = value
	case_dict["facts"] = facts
	current_case = case_dict
	if prev != value:
		emit_signal("facts_changed", [key])

func _meets_requires(reqs: Array) -> bool:
	for r_v in reqs:
		var r := String(r_v)
		if r.begins_with("!"):
			var name := r.substr(1)
			if get_fact(name, false): 
				return false
		else:
			if not get_fact(r, false):
				return false
	return true

func get_available_options(contact_id: String) -> Array:
	if typeof(current_case) != TYPE_DICTIONARY:
		return []
	var chats := (current_case as Dictionary).get("chats", {}) as Dictionary
	var chat := chats.get(contact_id, {}) as Dictionary
	var options: Array = chat.get("options", []) as Array
	var out: Array = []
	for opt_v in options:
		var opt: Dictionary = opt_v as Dictionary
		if bool(opt.get("used", false)):
			continue


		# ---- control de usos ----
		var repeatable := bool(opt.get("repeatable", false))
		var uses: int = int(opt.get("uses", 0))
		var max_uses: int
		if opt.has("max_uses"):
			max_uses = int(opt.get("max_uses", 1))
		else:
			max_uses = (0 if repeatable else 1)
		var already_used_once := bool(opt.get("used", false))

		var exhausted := false
		if max_uses > 0 and uses >= max_uses:
			exhausted = true
		elif max_uses == 1 and already_used_once and not repeatable:
			exhausted = true

		if exhausted:
			continue
		# --------------------------------

		var reqs: Array = opt.get("requires", []) as Array
		if _meets_requires(reqs):
			out.append(opt)
	return out

func apply_option(contact_id: String, option_id: String) -> Dictionary:
	# Devuelve: { "player_text": String, "npc_reply": Array[String] }
	if typeof(current_case) != TYPE_DICTIONARY:
		return {}

	var case_dict := current_case as Dictionary
	var chats := case_dict.get("chats", {}) as Dictionary
	var entry: Variant = chats.get(contact_id)

	# Soporta chat antiguo (Array) y nuevo (Dictionary con history/options)
	var chat: Dictionary
	var history: Array = []
	if typeof(entry) == TYPE_ARRAY:
		history = entry as Array
		chat = {"history": history}
	elif typeof(entry) == TYPE_DICTIONARY:
		chat = entry as Dictionary
		history = chat.get("history", []) as Array
	else:
		chat = {"history": []}
		history = []

	var options: Array = chat.get("options", []) as Array

	for i in options.size():
		var opt: Dictionary = options[i] as Dictionary
		if String(opt.get("id","")) == option_id and not bool(opt.get("used", false)):
			# marcar usada
			# ---- usos / repetible ----
			var repeatable := bool(opt.get("repeatable", false))
			var uses: int = int(opt.get("uses", 0)) + 1
			opt["uses"] = uses

			var max_uses: int
			if opt.has("max_uses"):
				max_uses = int(opt.get("max_uses", 1))
			else:
				max_uses = (0 if repeatable else 1)  # 0 = infinito

			# solo marcamos 'used' si se agota
			if max_uses > 0 and uses >= max_uses and not repeatable:
				opt["used"] = true

			options[i] = opt
			chat["options"] = options
			# --------------------------

			# aplicar efectos (usa el hook general)
			for e_v in (opt.get("effects", []) as Array):
				_process_effect(String(e_v))

			# persistir mensajes en history
			var player_text := String(opt.get("text",""))
			history.append({"from":"Yo", "text": player_text})
			for line_v in (opt.get("npc_reply", []) as Array):
				history.append({"from": _contact_name(contact_id), "text": String(line_v)})

			chat["history"] = history
			chats[contact_id] = chat
			case_dict["chats"] = chats
			current_case = case_dict

			return {
				"player_text": player_text,
				"npc_reply":  opt.get("npc_reply", []) as Array
			}

	return {}


# --- CATALOGO / PRESENTABLES -------------------------------

func get_evidence_catalog() -> Array:
	if typeof(current_case) != TYPE_DICTIONARY:
		return []
	return (current_case as Dictionary).get("evidence", []) as Array

func _get_evidence_map() -> Dictionary:
	var map: Dictionary = {}
	for ev_v in get_evidence_catalog():
		var ev := ev_v as Dictionary
		map[String(ev.get("id",""))] = ev
	return map

func get_presentable_evidence(contact_id: String) -> Array:
	if typeof(current_case) != TYPE_DICTIONARY:
		return []
	var chats := (current_case as Dictionary).get("chats", {}) as Dictionary
	var chat := chats.get(contact_id, {}) as Dictionary
	var used: Array = chat.get("used_evidence", []) as Array

	var owned := _owned_evidence_ids()
	var out: Array = []
	for ev_v in get_evidence_catalog():
		var ev := ev_v as Dictionary
		var rid := String(ev.get("id",""))
		if rid == "" or used.has(rid): continue
		if not owned.has(rid): continue   # <-- SOLO si la tienes
		var rx_all := ev.get("reactions", {}) as Dictionary
		if not rx_all.has(contact_id): continue
		var rx := rx_all.get(contact_id, {}) as Dictionary
		var reqs: Array = rx.get("requires", []) as Array
		if _meets_requires(reqs):
			out.append(ev)
	return out

func apply_evidence(contact_id: String, evidence_id: String) -> Dictionary:
	if typeof(current_case) != TYPE_DICTIONARY:
		return {}

	var case_dict := current_case as Dictionary
	var chats := case_dict.get("chats", {}) as Dictionary
	var entry: Variant = chats.get(contact_id)

	var chat: Dictionary
	var history: Array = []
	if typeof(entry) == TYPE_ARRAY:
		history = entry as Array
		chat = {"history": history}
	elif typeof(entry) == TYPE_DICTIONARY:
		chat = entry as Dictionary
		history = chat.get("history", []) as Array
	else:
		chat = {"history": []}
		history = []

	var ev_map := _get_evidence_map()
	if not ev_map.has(evidence_id):
		return {}

	var ev := ev_map.get(evidence_id, {}) as Dictionary
	var rx_all := ev.get("reactions", {}) as Dictionary
	if not rx_all.has(contact_id):
		return {}

	var rx := rx_all.get(contact_id, {}) as Dictionary
	if not _meets_requires(rx.get("requires", []) as Array):
		return {}

	# marcar evidencia usada con este contacto
	var used: Array = chat.get("used_evidence", []) as Array
	if not used.has(evidence_id):
		used.append(evidence_id)
	chat["used_evidence"] = used

	# aplicar efectos (hook general)
	for e_v in (rx.get("effects", []) as Array):
		_process_effect(String(e_v))

	# persistir conversacion por evidencia
	var player_text := String(rx.get("text", "Presento una prueba."))
	history.append({"from":"Yo", "text": player_text})
	for line_v in (rx.get("npc_reply", []) as Array):
		history.append({"from": _contact_name(contact_id), "text": String(line_v)})

	chat["history"] = history
	chats[contact_id] = chat
	case_dict["chats"] = chats
	current_case = case_dict

	return {
		"player_text": player_text,
		"npc_reply": (rx.get("npc_reply", []) as Array)
	}

func get_gallery_items() -> Array:
	if typeof(current_case) != TYPE_DICTIONARY:
		return []
	var raw: Array = (current_case as Dictionary).get("gallery", []) as Array
	var out: Array = []
	for v in raw:
		var item: Dictionary
		if typeof(v) == TYPE_STRING:
			item = {"id": String(v), "path": String(v), "requires": []}
		else:
			item = v as Dictionary
		var reqs: Array = item.get("requires", []) as Array
		if _meets_requires(reqs):
			out.append(item)
	return out

# --- EVIDENCE OWNERSHIP -----------------------------------

func _ensure_inventory() -> void:
	if not ("inventory" in GameState):
		GameState.inventory = {}
	elif typeof(GameState.inventory) != TYPE_DICTIONARY:
		GameState.inventory = {}

func grant_evidence(eid: String) -> void:
	_ensure_inventory()
	var inv: Dictionary = GameState.inventory as Dictionary
	inv[eid] = true
	GameState.inventory = inv
	print("[DB] evidence granted -> ", eid)

func _owned_evidence_ids() -> Array:
	_ensure_inventory()
	return (GameState.inventory as Dictionary).keys()

# --- HOOK GENERAL DE EFFECTS (para options y evidence) -----

func _process_effect(e: String) -> void:
	if e.begins_with("give_evidence:"):
		var id := e.substr("give_evidence:".length())
		grant_evidence(id)
		return
	if e.begins_with("unlock_gallery:"):
		var flag := "unlocked_" + e.substr("unlock_gallery:".length())
		set_fact(flag, true)
		return
	if e.begins_with("unlock_contact:"):
		var cid := e.substr("unlock_contact:".length())
		# bandera que usa en el 'requires' del contacto
		set_fact("contact_%s_unlocked" % cid, true)
		return
	# por defecto: fact booleana
	set_fact(e, true)

func _contact_name(id: String) -> String:
	if typeof(current_case) != TYPE_DICTIONARY:
		return id
	var contacts: Array = (current_case as Dictionary).get("contacts", []) as Array
	for c_v in contacts:
		var c := c_v as Dictionary
		if String(c.get("id","")) == id:
			return String(c.get("name", id))
	return id

func get_visible_contacts() -> Array:
	if typeof(current_case) != TYPE_DICTIONARY:
		return []
	var raw: Array = (current_case as Dictionary).get("contacts", []) as Array
	var out: Array = []
	for c_v in raw:
		var c := c_v as Dictionary
		var reqs: Array = c.get("requires", []) as Array
		if _meets_requires(reqs):
			out.append(c)
	return out
