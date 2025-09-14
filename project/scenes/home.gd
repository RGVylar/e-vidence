extends Control

@onready var btn_messages: BaseButton = %btn_messages
@onready var btn_gallery:  BaseButton = %btn_gallery
@onready var btn_mail:     BaseButton = %btn_mail
@onready var btn_back:     BaseButton = %BtnBack
@onready var lbl_case: Label = %CaseInfo

@export var messaging_scene: PackedScene = preload("res://scenes/apps/Messaging.tscn")
@export var gallery_scene:   PackedScene = preload("res://scenes/apps/Gallery.tscn")
@export var mail_scene:      PackedScene = preload("res://scenes/apps/Mail.tscn")

var router: Node = null
var SCENE_MAP: Dictionary

func _ready() -> void:
	print(">>> [Home] _ready() iniciado")
	
	SCENE_MAP = {
		"btn_messages": messaging_scene,
		"btn_gallery":  gallery_scene,
		"btn_mail":     mail_scene,
	}

	btn_back.pressed.connect(_on_back_pressed)

	var ok: bool = DB.load_case(GameState.current_case_id)
	print(">>> [Home] load_case(", GameState.current_case_id, ") -> ", ok)
	if lbl_case:
		lbl_case.text = "Caso cargado: tutorial" if ok else "No se pudo cargar el caso"
	if not ok:
		push_warning("No se pudo cargar el caso: %s" % str(GameState.current_case_id))

	router = get_node_or_null("/root/Router")
	if router:
		router.set("root", self)
		print(">>> [Home] Router encontrado:", router)
	else:
		push_warning("Router no encontrado (usaré fallback change_scene)")

	for b in [btn_messages, btn_gallery, btn_mail]:
		b.custom_minimum_size = Vector2(160, 160)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(_on_btn_pressed.bind(b.name))
		print(">>> [Home] Conectado botón:", b.name)

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
	print(">>> [Home] Pulsado BtnBack -> Home.tscn")
	get_tree().change_scene_to_file("res://scenes//Main.tscn")
