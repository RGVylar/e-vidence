extends Control

func _on_evidence_opened(evidence_id: Dictionary) -> void:
	GameState.add_evidence(evidence_id)
