extends Control

@onready var paham_button: TextureButton = $ButtonMengerti
@onready var fade_black: ColorRect = $FadeBlack


func _ready() -> void:
	fade_black.color = Color(0, 0, 0, 0)

	paham_button.pressed.connect(_on_paham_pressed)


func _on_paham_pressed() -> void:
	paham_button.disabled = true

	var tween = create_tween()

	tween.tween_property(
		fade_black,
		"color:a",
		1.0,
		1.0
	)

	await tween.finished

	get_tree().change_scene_to_file("res://Scene/gameplay.tscn")
