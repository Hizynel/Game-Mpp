extends Control

# ==============================================================================
# SCRIPT HANDLER UNTUK SCENE BINTANG (bintang-1, bintang-2, bintang-3)
# ==============================================================================

func _ready() -> void:
	_setup_buttons()


func _setup_buttons() -> void:
	# Cari TextureButton (Peringkat) dan TextureButton2 (Back) secara otomatis
	var buttons = find_children("*", "TextureButton", true, false)
	for btn in buttons:
		if btn.name == "TextureButton":
			# Tombol Peringkat
			btn.pressed.connect(_on_peringkat_pressed)
		elif btn.name == "TextureButton2":
			# Tombol Back
			btn.pressed.connect(_on_back_pressed)


func _on_peringkat_pressed() -> void:
	print("[StarUI] Membuka halaman Leaderboard/Peringkat...")
	get_tree().change_scene_to_file("res://Scene/leaderboard.tscn")


func _on_back_pressed() -> void:
	print("[StarUI] Kembali ke Main Menu...")
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
