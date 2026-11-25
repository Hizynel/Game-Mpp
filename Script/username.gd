extends Control

@onready var username_input: LineEdit = $PanelContainer/VBoxContainer/UsernameInput
@onready var password_input: LineEdit = $PanelContainer/VBoxContainer/PasswordInput
@onready var lanjut_button: Button = $LanjutButton
@onready var status_label: Label = $PanelContainer/VBoxContainer/StatusLabel


func _ready() -> void:
	lanjut_button.pressed.connect(_on_lanjut_pressed)
	status_label.text = ""
	# Pastikan field email & password kosong saat pertama kali masuk
	username_input.text = ""
	password_input.text = ""


func _on_lanjut_pressed() -> void:
	var identifier = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()

	if identifier == "":
		status_label.text = "⚠️ Email wajib diisi!"
		status_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
		return

	if password == "":
		status_label.text = "⚠️ Password wajib diisi!"
		status_label.add_theme_color_override("font_color", Color(1, 1, 0.4))
		return

	status_label.text = "Menghubungkan ke API..."
	status_label.add_theme_color_override("font_color", Color(1, 1, 1))
	lanjut_button.disabled = true

	# Panggil API login P2R
	NetworkManager.login_player(identifier, password, func(success: bool, msg: String, coins: int):
		lanjut_button.disabled = false
		if success:
			status_label.text = "✅ Login Berhasil! Saldo: %d Coins" % coins
			status_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
			_fade_to_black_and_change_scene("res://Scene/main_menu.tscn")
		else:
			status_label.text = "❌ " + msg
			status_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	)


func _fade_to_black_and_change_scene(target_scene: String) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, 0.8).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().change_scene_to_file(target_scene)
