## DecoButton — Button sottoclasse con override virtuale di _get_drag_data.
##
## Motivazione: set_drag_forwarding() su Button non inizia il drag in Godot 4.5
## (callback setup e` OK ma manca il trigger al mouse_down). Il pattern che
## funziona affidabilmente in Godot 4 e` override diretto del hook virtuale
## _get_drag_data su una sottoclasse del Control draggable.
##
## Riferimenti di pattern consultati:
## - jlucaso1/drag-drop-inventory (TextureRect override _get_drag_data)
## - jeroenheijmans/sample-godot-drag-drop-from-control-to-node2d (MarginContainer override)
##
## Usage in deco_panel.gd._create_drag_button:
##   var btn := DecoButton.new()
##   btn.set_meta("drag_data", { item_id=..., sprite_path=..., ... })
##   # no set_drag_forwarding needed
extends Button
class_name DecoButton


func _get_drag_data(_at_position: Vector2) -> Variant:
	var drag_data: Dictionary = get_meta("drag_data", {})
	if drag_data.is_empty():
		AppLogger.warn("DecoButton", "drag_no_meta", {"btn_name": name})
		return null

	# Drag preview: texture pixel art scalata ~50% rispetto all'originale
	# scaled-in-world, con filtro nearest (coerente pixel art).
	var preview := TextureRect.new()
	var tex := load(drag_data.get("sprite_path", "")) as Texture2D
	if tex != null:
		preview.texture = tex
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var preview_scale: float = drag_data.get("item_scale", 1.0)
		preview.custom_minimum_size = tex.get_size() * preview_scale * 0.5
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	set_drag_preview(preview)
	AppLogger.info(
		"DecoButton",
		"drag_started",
		{
			"item_id": drag_data.get("item_id", ""),
			"pos": _at_position,
		}
	)
	return drag_data
