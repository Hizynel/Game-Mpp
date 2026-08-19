extends Control

@onready var bg_tuto: Sprite2D = $BgTuto
@onready var paham_button: Button = $ButtonMengerti
@onready var label: Label = $Label


func _ready() -> void:
	# Langsung tampil normal
	bg_tuto.modulate = Color(0.3, 0.3, 0.3, 1)
	label.modulate.a = 1.0
	paham_button.modulate.a = 1.0

	paham_button.pressed.connect(_on_paham_pressed)


func _on_paham_pressed() -> void:
	paham_button.disabled = true

	# Fade ke hitam
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

	# Tunggu sampai layar hitam
	await tween.finished

	# Baru pindah scene
	get_tree().change_scene_to_file("res://NAMA_SCENE_GAME.tscn")
