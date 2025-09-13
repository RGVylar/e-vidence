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
	print("contacts => ", contacts)

	for c_v in contacts:
		var c: Dictionary = c_v as Dictionary
		var id: String = c.get("id", "") as String
		var name: String = c.get("name", id) as String

		var btn := Button.new()
		btn.text = name
		btn.pressed.connect(_on_contact_pressed.bind(id))
		list.add_child(btn)
		print("added button:", name, "(", id, ")")

func _on_contact_pressed(contact_id: String) -> void:
	print("contact pressed:", contact_id)
	GameState.current_thread = contact_id
	print("changing scene to Chat.tscn")
	get_tree().change_scene_to_file("res://scenes//apps//Chat.tscn")

func _pretty_contact(id: String) -> String:
	# Mapeo simple; luego podrás cargar nombres/avatars desde el JSON
	if id == "friend_1":
		return "Amigo"
	return id.capitalize()

	
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes//Home.tscn")
