extends CharacterBody2D
const SPEED: float = 40.0

var direction: Vector2

func _physics_process(_delta: float) -> void:
	direction = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	velocity = SPEED * direction
	move_and_slide()
	_animate()


func aim_weapon(target_direction: Vector2) -> void:
	$CurrentWeapon.look_at($CurrentWeapon.global_position + target_direction)
	%Weapon.scale.y = -1.0 if target_direction.x < 0.0 else 1.0
	%Weapon.shoot(target_direction)


func _animate() -> void:
	if direction == Vector2.ZERO:
		var current := $AnimatedSprite2D.animation as String
		if current.begins_with("walk_"):
			var idle_anim: StringName
			match current:
				"walk_side":      idle_anim = &"idle_side"
				"walk_side_down": idle_anim = &"idle_vertical_down"
				"walk_down":      idle_anim = &"idle_down"
				"walk_side_up":   idle_anim = &"idle_vertical_up"
				"walk_up":        idle_anim = &"idle_up"
			$AnimatedSprite2D.play(idle_anim)
		return

	# Flip horizontally for left-facing directions
	$AnimatedSprite2D.flip_h = direction.x < 0.0

	# Determine animation based on angle (8 directions, 45° each)
	var angle := direction.angle()
	var sector := int(round(angle / (PI / 4.0))) % 8
	if sector < 0:
		sector += 8

	var anim: StringName
	match sector:
		0:  anim = &"walk_side"       # right
		1:  anim = &"walk_side_down"  # down-right
		2:  anim = &"walk_down"       # down
		3:  anim = &"walk_side_down"  # down-left  (flip_h)
		4:  anim = &"walk_side"       # left        (flip_h)
		5:  anim = &"walk_side_up"    # up-left     (flip_h)
		6:  anim = &"walk_up"         # up
		7:  anim = &"walk_side_up"    # up-right

	$AnimatedSprite2D.play(anim)

		
	
