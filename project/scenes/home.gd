## Home screen interface for the smartphone simulation.
##
## This script manages the main smartphone home screen with app icons
## that navigate to different parts of the investigation game.
extends Control

## App button references
@onready var btn_messages: BaseButton = %btn_messages
@onready var lbl_case: Label = %CaseInfo
@onready var btn_gallery:  BaseButton = %btn_gallery
@onready var btn_mail:     BaseButton = %btn_mail
@onready var btn_back:     BaseButton = %BtnBack
@onready var btn_browser:     BaseButton = %btn_browser

## Pre-loaded app scenes
@export var messaging_scene: PackedScene = preload("res://scenes/apps/Messaging.tscn")
@export var gallery_scene:   PackedScene = preload("res://scenes/apps/Gallery.tscn")
@export var mail_scene:      PackedScene = preload("res://scenes/apps/Mail.tscn")
@export var browser_scene:   PackedScene = preload("res://scenes/apps/Browser.tscn")

## Router reference for navigation
var router: Node = null
## Maps button names to their corresponding scenes
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

	var case_id := String(GameState.current_case_id)
	var ok := true

	# Solo recarga si hace falta (y evita llamar dos veces)
	var needs_load := typeof(DB.current_case) != TYPE_DICTIONARY \
		 or (DB.current_case as Dictionary).is_empty() \
		 or String((DB.current_case as Dictionary).get("_id","")) != case_id
	if needs_load:
		ok = DB.load_case(case_id)

	print(">>> [Home] load_case(", case_id, ") -> ", ok)

	if lbl_case:
		if ok:
			var display := case_id
			if display.begins_with("case_"):
				display = display.substr("case_".length())  # quita el prefijo
			lbl_case.text = "Caso cargado: %s" % display
		else:
			lbl_case.text = "No se pudo cargar el caso"

	if not ok:
		push_warning("No se pudo cargar el caso: %s" % case_id)

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
	print(">>> [Home] Pulsado BtnBack -> Home.tscn")
	get_tree().change_scene_to_file("res://scenes//Main.tscn")
