extends Control

@onready var bg_tuto: Sprite2D = $BgTuto
@onready var paham_button: Button = $ButtonMengerti
@onready var label: Label = $Label


func _ready() -> void:
	# Awalnya background hitam
	bg_tuto.modulate = Color(0, 0, 0, 1)

	# Label dan button awalnya transparan
	label.modulate.a = 0.0
	paham_button.modulate.a = 0.0

	# Hubungkan tombol
	paham_button.pressed.connect(_on_paham_pressed)

	# Fade IN awal
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		bg_tuto,
		"modulate",
		Color(0.3, 0.3, 0.3, 1),
		4.0
	)

	tween.tween_property(
		label,
		"modulate:a",
		1.0,
		4.0
	)

	tween.tween_property(
		paham_button,
		"modulate:a",
		1.0,
		4.0
	)


func _on_paham_pressed() -> void:
	# Supaya tombol tidak bisa ditekan berkali-kali
	paham_button.disabled = true

	# Fade OUT sekali
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		bg_tuto,
		"modulate",
		Color(0, 0, 0, 1),
		1.0
	)

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		1.0
	)

	tween.tween_property(
		paham_button,
		"modulate:a",
		0.0,
		1.0
	)

	# Tunggu sampai fade selesai
	await tween.finished

	# Baru pindah scene
	_on_tutorial_selesai()


func _on_tutorial_selesai() -> void:
	get_tree().change_scene_to_file("res://NAMA_SCENE_GAME.tscn")
