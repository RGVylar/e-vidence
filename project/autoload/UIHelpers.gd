## UI utility functions for common interface operations.
##
## This autoload provides reusable UI functionality across the application,
## particularly for image viewing and overlay management.
extends Node

## Shows an image in a fullscreen lightbox overlay.
## Creates a modal overlay with the provided texture, allowing the user
## to view it at full size and close it by clicking or pressing ESC.
## @param tex: Texture2D - The texture to display in the lightbox
func show_lightbox(tex: Texture2D) -> void:
	if tex == null:
		return

	var overlay: Control = Control.new()
	overlay.name = "_Lightbox"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	var big: TextureRect = TextureRect.new()
	big.texture = tex
	big.expand = true
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big.offset_left = 48
	big.offset_right = -48
	big.offset_top = 48
	big.offset_bottom = -48
	overlay.add_child(big)

	overlay.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) \
		or (ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE):
			overlay.queue_free()
	)

	var tween: Tween = create_tween()
	overlay.modulate = Color(1,1,1,0)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
