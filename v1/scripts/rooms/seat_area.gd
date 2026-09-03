## SeatArea — area interagibile di una sedia (fase 5, spec 2026-08-14).
## Creata da room_base sotto le decorazioni "sittable": il tasto E del
## personaggio la trova sul layer interagibili e delega a sit_on() del
## player (dispatch per capacita`, come i mess). Come i mess, annuncia la
## propria presenza al HUD ("Premi E") quando il personaggio si avvicina.
extends Area2D

## Lo sprite-decorazione a cui questa seduta appartiene.
var seat: Sprite2D = null
## Id di catalogo della sedia (per il prompt del HUD).
var item_id: String = ""
var _prompt_shown: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _exit_tree() -> void:
	# Pareggia il contatore del HUD se la sedia sparisce sotto i piedi.
	_release_prompt()


## True se l'interazione e` stata accettata (il personaggio si e` seduto).
func on_interact(player: Node) -> bool:
	if seat == null or not is_instance_valid(seat):
		return false
	if GameManager.is_decoration_mode:
		return false  # in edit mode le sedie si spostano, non si usano
	if player.has_method("sit_on"):
		player.call("sit_on", seat)
		_release_prompt()  # da seduti E fa alzare: "sederti" mentirebbe
		return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not _prompt_shown:
		_prompt_shown = true
		SignalBus.interaction_available.emit(item_id, "sit")


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_release_prompt()


func _release_prompt() -> void:
	if _prompt_shown:
		_prompt_shown = false
		SignalBus.interaction_unavailable.emit()
