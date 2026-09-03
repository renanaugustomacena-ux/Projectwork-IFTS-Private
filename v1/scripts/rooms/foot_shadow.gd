## FootShadow — Ombra ovale procedurale sotto un'entita` a terra (personaggio,
## gatto). Nessuna arte: un cerchio schiacciato in _draw(), sempre dietro al
## padre (z relativo -1 + show_behind_parent). Il padre la posiziona sul punto
## di contatto con il pavimento (_foot_offset), cosi` l'ombra segue i piedi e
## non il centro dello sprite — il collider e` l'autorita`, il visivo segue.
extends Node2D

## Semiasse orizzontale in pixel; quello verticale e` radius * squash.
@export var radius := 10.0
## Rapporto altezza/larghezza dell'ellisse (vista dall'alto-3/4).
@export var squash := 0.4
@export var shadow_color := Color(0, 0, 0, 0.22)


func _ready() -> void:
	z_as_relative = true
	z_index = -1
	show_behind_parent = true
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, shadow_color)
