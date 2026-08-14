## SeatArea — area interagibile di una sedia (fase 5, spec 2026-08-14).
## Creata da room_base sotto le decorazioni "sittable": il tasto E del
## personaggio la trova sul layer interagibili e delega a sit_on() del
## player (dispatch per capacita`, come i mess).
extends Area2D

## Lo sprite-decorazione a cui questa seduta appartiene.
var seat: Sprite2D = null


func on_interact(player: Node) -> void:
	if seat == null or not is_instance_valid(seat):
		return
	if GameManager.is_decoration_mode:
		return  # in edit mode le sedie si spostano, non si usano
	if player.has_method("sit_on"):
		player.call("sit_on", seat)
