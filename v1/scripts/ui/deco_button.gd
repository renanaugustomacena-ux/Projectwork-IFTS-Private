## DecoButton — draggable catalog item, implemented as TextureRect (not Button).
##
## ## Perche TextureRect e non Button (cambio pattern 2026-04-17)
##
## La prima implementazione estendeva `Button` con override `_get_drag_data`.
## In test headless `pressed.emit()` apriva correttamente un panel, ma in-game
## i click reali non triggeravano ne il pressed signal ne la drag detection.
## La causa e documentata in Godot 4 community posts e verificata nei
## reference repo:
##
## - jlucaso1/drag-drop-inventory:   `extends TextureRect` (no Button)
## - jeroenheijmans/drag-drop-sample: `extends MarginContainer` (no Button)
##
## Il problema con Button: la sua logica interna `_pressing_inside` +
## `_press_inside_area` interferisce con il flow di Godot 4 per drag
## detection (Viewport aspetta mouse_move threshold tra press e release).
## Quando Button intercetta il mouse_down via `_gui_input`, il viewport
## fatica a far partire la drag detection che chiama `_get_drag_data`.
##
## TextureRect e un Control "nudo": riceve eventi ma non ha logica press.
## Il drag detection funziona fuori dalla scatola.
##
## Meta `drag_data` settato da `deco_panel.gd._create_drag_button` contiene
## `item_id`, `sprite_path`, `item_scale`, `placement_type` — stesso payload
## che DropZone si aspetta in `_drop_data`.
class_name DecoButton
extends TextureRect


func _ready() -> void:
	# Controls devono avere mouse_filter STOP (default) per ricevere clicks
	# ed essere considerati per drag detection dal viewport.
	# Preserviamo explicit per robustezza contro regressioni theme/parent.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Pixel art: no smoothing sulla texture scalata
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Centered so the preview looks natural relative to the catalog cell.
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE


func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_data: Dictionary = get_meta("drag_data", {})
	if drag_data.is_empty():
		AppLogger.warn("DecoButton", "drag_no_meta", {"btn_name": name})
		return null

	# Drag preview: texture pixel art scalata ~50% dell'item_scale in-world
	# (il preview segue il cursore quindi deve essere ridotto per non ingombrare).
	var preview := TextureRect.new()
	var tex := load(drag_data.get("sprite_path", "")) as Texture2D
	if tex != null:
		preview.texture = tex
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var preview_scale: float = drag_data.get("item_scale", 1.0)
		preview.custom_minimum_size = tex.get_size() * preview_scale * 0.5
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	set_drag_preview(preview)
	(
		AppLogger
		. info(
			"DecoButton",
			"drag_started",
			{
				"item_id": drag_data.get("item_id", ""),
				"pos": _at_position,
			}
		)
	)
	return drag_data
