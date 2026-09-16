extends Control
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var start_button: TextureButton = $Button
@onready var quit_button: TextureButton = $Button2
@onready var logo: Sprite2D = $Logo

func _ready() -> void:
	video_player.finished.connect(_on_video_finished)
	_fade_in()

func _fade_in() -> void:
	modulate = Color.BLACK
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 1.5).set_trans(Tween.TRANS_SINE)

func _on_button_pressed() -> void:
	start_button.hide()
	quit_button.hide()
	logo.hide()
	video_player.play()

func _on_video_finished() -> void:
	get_tree().change_scene_to_file("res://Scene/tutorial.tscn")

func _on_button_2_pressed() -> void:
	get_tree().quit()
