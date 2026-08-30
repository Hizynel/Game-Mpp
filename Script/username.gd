extends Control

@onready var username_input = $PanelContainer/VBoxContainer/UsernameInput
@onready var lanjut_button = $Panel/LanjutButton
func _ready():
	lanjut_button.pressed.connect(_on_lanjut_pressed)


func _on_lanjut_pressed():
	var username = username_input.text.strip_edges()

	if username == "":
		print("Username belum diisi!")
		return

	print("Username:", username)

	lanjut_button.disabled = true

	_fade_to_black_and_change_scene("res://Scene/main_menu.tscn")


func _fade_to_black_and_change_scene(target_scene: String):
	var tween = create_tween()
	
	# Mengubah modulasi warna scene saat ini menjadi Hitam Pekat dalam durasi 1.5 detik
	# Efek TRANS_SINE membuat perubahan warnanya terasa lebih mulus
	tween.tween_property(self, "modulate", Color.BLACK, 1.5).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	get_tree().change_scene_to_file(target_scene)
