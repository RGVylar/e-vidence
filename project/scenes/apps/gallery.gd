extends Control

@onready var btn_back: Button = %BtnBack
@onready var grid: GridContainer = %GridContainer 

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)
	if typeof(DB.current_case) != TYPE_DICTIONARY or (DB.current_case as Dictionary).is_empty():
		DB.load_case(GameState.current_case_id)
	DB.facts_changed.connect(func(_k): _render_gallery())
	_render_gallery()

func _on_evidence_opened(evidence_id: Dictionary) -> void:
	GameState.add_evidence(evidence_id)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes//Home.tscn")

func _render_gallery() -> void:
	for n in grid.get_children(): n.queue_free()
	var items: Array = []
	if DB.has_method("get_gallery_items"):
		items = DB.get_gallery_items()
	else:
		# fallback: todo
		var arr: Array = (DB.current_case as Dictionary).get("gallery", []) as Array
		for v in arr:
			var item: Dictionary
			if typeof(v) == TYPE_STRING:
				item = {"id": String(v), "path": String(v)}  # opcional: "requires": []
			else:
				item = v as Dictionary
			items.append(item)

	for it_v in items:
		var it := it_v as Dictionary
		var tex := load(String(it.get("path","")))
		if tex is Texture2D:
			var tr := TextureRect.new()
			tr.expand = true
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.custom_minimum_size = Vector2(320, 320)
			tr.texture = tex
			grid.add_child(tr)
