extends Area2D

var lane_positions = [-460.0, -29.0, 445.0]  # kiri, tengah, kanan
var current_lane := 1  # mulai di tengah
var lane_switch_speed := 0.5  # durasi geser antar lane (detik)

func _ready() -> void:
	position.x = lane_positions[current_lane]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			move_lane(-1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			move_lane(1)

func move_lane(direction: int) -> void:
	var target_lane = current_lane + direction
	target_lane = clamp(target_lane, 0, lane_positions.size() - 1)
	if target_lane == current_lane:
		return  # udah di ujung, ga bisa geser lagi
	current_lane = target_lane
	var tween = create_tween()
	tween.tween_property(
		self,
		"position:x",
		lane_positions[current_lane],
		lane_switch_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_area_entered(area: Area2D) -> void:
	if area.is_good:
		get_parent().add_score(10)
		show_score_popup("+10", Color(0.1, 1.0, 0.1))
	else:
		get_parent().subtract_score(15)
		show_score_popup("-15", Color(1.0, 0.1, 0.1))
	area.queue_free()

func show_score_popup(popup_text: String, color: Color) -> void:
	var popup = Label.new()
	popup.text = popup_text
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_font_size_override("font_size", 32)
	popup.z_index = 100
	
	# Memasukkan popup ke parent (Node2D utama tempat karakter berada)
	get_parent().add_child(popup)
	
	# Ambil posisi visual karakter dari Sprite2D
	popup.global_position = $Sprite2D.global_position + Vector2(-20, -50)
	
	# Animasi naik + menghilang
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		popup,
		"position:y",
		popup.position.y - 40,
		0.6
	)
	tween.tween_property(
		popup,
		"modulate:a",
		0.0,
		0.6
	)
	tween.chain().tween_callback(popup.queue_free)
