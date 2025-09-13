extends Control

# Ejemplo dentro de Gallery.gd al pulsar una tarjeta/ítem
func _on_evidence_opened(evidence_id: Dictionary) -> void:
	GameState.add_evidence(evidence_id)
