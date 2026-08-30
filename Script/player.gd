extends Area2D
@export var speed := 500.0

func _process(delta):
	var arah = 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		arah -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		arah += 1
	position.x += arah * speed * delta
	position.x = clamp(position.x, -544, 486.0)

func _on_area_entered(area):
	if area.is_good:
		get_parent().add_score(10)
	else:
		get_parent().subtract_score(15)
	area.queue_free()
