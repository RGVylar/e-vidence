extends Control

@onready var btn_back: Button = %BtnBack

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_evidence_opened(evidence_id: Dictionary) -> void:
	GameState.add_evidence(evidence_id)

func _on_back_pressed() -> void:
	if SaveGame.has_method("save_current_game"):
		SaveGame.save_current_game()
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
