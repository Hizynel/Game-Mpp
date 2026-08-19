extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var start_button: Button = $Button
@onready var quit_button: Button = $Button2


func _ready() -> void:
	video_player.finished.connect(_on_video_finished)


func _on_button_pressed() -> void:
	start_button.hide()
	quit_button.hide()
	video_player.play()


func _on_video_finished() -> void:
	get_tree().change_scene_to_file("res://Scene/tutorial.tscn")


func _on_button_2_pressed() -> void:
	get_tree().quit()
