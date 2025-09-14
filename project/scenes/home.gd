extends Control

@onready var btn_messages: BaseButton = $GridContainer/btn_messages
@onready var btn_gallery:  BaseButton = $GridContainer/btn_gallery
@onready var btn_mail:     BaseButton = $GridContainer/btn_mail
@onready var lbl_case: Label = $CaseInfo   # crea un Label en la escena y llámalo CaseInfo

var router: Node = null  # autoload de tipo Node

const SCENE_MAP := {
	"btn_messages": "res://scenes/apps/Messaging.tscn",
	"btn_gallery":  "res://scenes/apps/Gallery.tscn",
	"btn_mail":     "res://scenes/apps/Mail.tscn",
}

func _ready() -> void:
	# DB y GameState son Script Singletons → se usan directos
	var ok: bool = DB.load_case(GameState.current_case_id)
	
	if lbl_case:
		lbl_case.text = "Caso cargado: tutorial" if ok else "No se pudo cargar el caso"
	if not ok:
		push_warning("No se pudo cargar el caso: %s" % str(GameState.current_case_id))

	# Router sí es Node autoload
	router = get_node_or_null("/root/Router")
	if router:
		router.set("root", self)
	else:
		push_warning("Router no encontrado (usaré fallback change_scene)")

	for b in [btn_messages, btn_gallery, btn_mail]:
		b.custom_minimum_size = Vector2(160, 160)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.pressed.connect(_on_btn_pressed.bind(b.name))

func _on_btn_pressed(btn_name: String) -> void:  # <- renombrado (evita shadowing)
	var path: String = (SCENE_MAP.get(btn_name, "") as String)
	if path.is_empty():
		push_warning("No hay ruta configurada para: %s" % btn_name)
		return
	if not FileAccess.file_exists(path):
		push_error("Escena no encontrada: %s" % path)
		return

	if router and (router.has_method("go") or router.has_method("goto")):
		if router.has_method("go"): router.call("go", path)
		else:                      router.call("goto", path)
	else:
		get_tree().change_scene_to_file(path)
