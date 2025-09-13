extends Control

@onready var btn_start: Button = %BtnStart

func _ready() -> void:
	btn_start.pressed.connect(_on_start_pressed)
	
func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes//Home.tscn")
