extends Control

@onready var btn_messages: BaseButton = %btn_messages
@onready var lbl_case: Label = %CaseInfo

@onready var btn_gallery:  BaseButton = %btn_gallery
@onready var btn_mail:     BaseButton = %btn_mail
@onready var btn_back:     BaseButton = %BtnBack
@onready var btn_browser:     BaseButton = %btn_browser

@export var messaging_scene: PackedScene = preload("res://scenes/apps/Messaging.tscn")
@export var gallery_scene:   PackedScene = preload("res://scenes/apps/Gallery.tscn")
@export var mail_scene:      PackedScene = preload("res://scenes/apps/Mail.tscn")
@export var browser_scene:   PackedScene = preload("res://scenes/apps/Browser.tscn")

var router: Node = null
var SCENE_MAP: Dictionary

func _ready() -> void:
	print(">>> [Home] _ready() iniciado")
	
	SCENE_MAP = {
		"btn_messages": messaging_scene,
		"btn_gallery":  gallery_scene,
		"btn_mail":     mail_scene,
		"btn_browser":  browser_scene
	}

	btn_back.pressed.connect(_on_back_pressed)

	# Load case if we have a current_case_id
	var ok: bool = false
	if not GameState.current_case_id.is_empty():
		ok = DB.load_case(GameState.current_case_id)
		print(">>> [Home] load_case(", GameState.current_case_id, ") -> ", ok)
	else:
		print(">>> [Home] No current_case_id set")
	
	if lbl_case:
		var save_name = ""
		if SaveGame.has_method("get_current_save_name"):
			save_name = SaveGame.get_current_save_name()
		var case_text = "Caso: %s" % GameState.current_case_id if ok else "No hay caso cargado"
		if not save_name.is_empty():
			lbl_case.text = "Jugador: %s | %s" % [save_name, case_text]
		else:
			lbl_case.text = case_text
	if not ok and not GameState.current_case_id.is_empty():
		push_warning("No se pudo cargar el caso: %s" % str(GameState.current_case_id))

	router = get_node_or_null("/root/Router")
	if router:
		router.set("root", self)
		print(">>> [Home] Router encontrado:", router)
	else:
		push_warning("Router no encontrado (usaré fallback change_scene)")

	for btn_name in SCENE_MAP.keys():
		var btn: BaseButton = get_node_or_null("%" + btn_name) as BaseButton
		if btn == null:
			push_warning("Botón no encontrado: %" + btn_name)
			continue
		btn.custom_minimum_size = Vector2(160, 160)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_btn_pressed.bind(btn_name))

func _on_btn_pressed(btn_name: String) -> void:
	print(">>> [Home] Pulsado:", btn_name)
	var scn: PackedScene = SCENE_MAP.get(btn_name, null)
	if scn == null:
		print(">>> [Home] Falta escena para:", scn)
		push_warning("Falta escena para: " + btn_name)
		return

	if router and router.has_method("go"):
		var path := (scn as PackedScene).resource_path
		print(">>> [Home] Router.go -> ", path)
		router.call("go", path)
	else:
		print(">>> [Home] Fallback change_scene_to_packed")
		get_tree().change_scene_to_packed(scn)
		
func _on_back_pressed() -> void:
	print(">>> [Home] Pulsado BtnBack -> SaveGameManager.tscn")
	# Save current game before going back
	if SaveGame.has_method("save_current_game"):
		SaveGame.save_current_game()
	get_tree().change_scene_to_file("res://scenes/SaveGameManager.tscn")
