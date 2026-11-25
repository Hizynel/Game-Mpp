extends Control

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var start_button: TextureButton = $Button
@onready var quit_button: TextureButton = $Button2
@onready var peringkat_button: TextureButton = $Button3
@onready var logo: Sprite2D = $Logo
@onready var click_sound: AudioStreamPlayer2D = $Button/click_sound
@onready var bgm_music: AudioStreamPlayer2D = $AudioStreamPlayer2D

# UI Sistem Coins Pojok Kiri Atas
@onready var coins_label: Label = $TopLeftCoinsBar/VBoxContainer/CoinsLabel
@onready var user_info_label: Label = $TopLeftCoinsBar/VBoxContainer/UserInfoLabel

# Popup Koin Kurang / Gagal Memulai
@onready var insufficient_popup: Control = $InsufficientCoinsPopup
@onready var popup_message: Label = $InsufficientCoinsPopup/Panel/VBox/Message
@onready var btn_close_popup: Button = $InsufficientCoinsPopup/Panel/VBox/BtnClosePopup


func _ready() -> void:
	video_player.finished.connect(_on_video_finished)
	peringkat_button.pressed.connect(_on_peringkat_pressed)
	quit_button.pressed.connect(_on_button_2_pressed)
	btn_close_popup.pressed.connect(func(): insufficient_popup.hide())

	NetworkManager.coins_updated.connect(_on_coins_updated)
	_update_coins_ui(NetworkManager.current_coins)

	_fade_in()


func _fade_in() -> void:
	modulate = Color.BLACK
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)


func _on_coins_updated(new_coins: int) -> void:
	_update_coins_ui(new_coins)


func _update_coins_ui(coins: int) -> void:
	var name_str = NetworkManager.current_display_name
	if name_str == "":
		name_str = NetworkManager.current_username
	if name_str == "":
		name_str = "Pemain P2R"

	var cost = NetworkManager.PLAY_GAME_COST
	coins_label.text = "🪙 %s Coins" % _format_number(coins)
	user_info_label.text = "Akun: %s | Biaya: %d Coin" % [name_str, cost]


func _format_number(num: int) -> String:
	var s = str(num)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res


# ==============================================================================
# MEKANISME SPEND COIN SETIAP MULAI MAIN
# ==============================================================================
func _on_button_pressed() -> void:
	click_sound.play()

	var cost = NetworkManager.PLAY_GAME_COST
	if NetworkManager.current_coins < cost:
		_show_error_popup("Koin Anda tidak cukup! Dibutuhkan %d Coin untuk bermain, koin Anda: %d Coins.\nSilakan hubungi admin untuk topup." % [cost, NetworkManager.current_coins])
		return

	start_button.disabled = true

	# 1. Potong koin game_entry (1 coin)
	NetworkManager.deduct_coins("game_entry", cost, func(success: bool, remaining_coins: int, err_msg: String):
		if not success:
			start_button.disabled = false
			_show_error_popup("Gagal memulai permainan!\n" + err_msg)
			return

		print("[MainMenu] Koin game_entry berhasil dipotong. Membuka sesi game P2R...")

		# 2. Buka session resmi di P2R
		NetworkManager.start_game_session(func(session_ok: bool, session_id: String):
			start_button.disabled = false
			bgm_music.stop()

			start_button.hide()
			quit_button.hide()
			peringkat_button.hide()
			logo.hide()
			video_player.play()
		)
	)


func _show_error_popup(message: String) -> void:
	popup_message.text = message
	insufficient_popup.show()


func _on_video_finished() -> void:
	get_tree().change_scene_to_file("res://Scene/tutorial.tscn")


func _on_button_2_pressed() -> void:
	click_sound.play()
	get_tree().quit()


func _on_peringkat_pressed() -> void:
	click_sound.play()
	get_tree().change_scene_to_file("res://Scene/leaderboard.tscn")
