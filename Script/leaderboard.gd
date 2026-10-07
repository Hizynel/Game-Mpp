extends Control

# ==============================================================================
# LEADERBOARD CONTROLLER (PAPAN PERINGKAT)
# ==============================================================================

@onready var back_button: TextureButton = $BackButton
@onready var scores_container: VBoxContainer = $Panel/ScrollContainer/ScoresList
@onready var status_label: Label = $Panel/StatusLabel


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	NetworkManager.leaderboard_received.connect(_on_leaderboard_received)

	status_label.text = "Memuat data peringkat dari database..."
	status_label.show()

	# Minta data leaderboard ke backend API
	NetworkManager.get_leaderboard()


func _on_leaderboard_received(success: bool, data: Array) -> void:
	# Bersihkan daftar lama jika ada
	for child in scores_container.get_children():
		child.queue_free()

	if not success or data.is_empty():
		status_label.text = "Belum ada catatan skor di papan peringkat."
		status_label.show()
		return

	status_label.hide()

	# Render setiap entri skor
	for i in range(data.size()):
		var entry = data[i]
		var rank = i + 1
		var username = str(entry.get("username", "Anonim"))
		var score = str(entry.get("score", 0))
		var combo = str(entry.get("max_combo", 0))

		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 48)

		# Label Ranking
		var rank_lbl = Label.new()
		if rank == 1:
			rank_lbl.text = "🥇 #1"
			rank_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1)) # Emas
		elif rank == 2:
			rank_lbl.text = "🥈 #2"
			rank_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85)) # Perak
		elif rank == 3:
			rank_lbl.text = "🥉 #3"
			rank_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.2)) # Perunggu
		else:
			rank_lbl.text = "   #%d" % rank
			rank_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

		rank_lbl.custom_minimum_size = Vector2(100, 0)
		rank_lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(rank_lbl)

		# Label Nama Pemain
		var name_lbl = Label.new()
		name_lbl.text = username
		name_lbl.custom_minimum_size = Vector2(350, 0)
		name_lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(name_lbl)

		# Label Skor
		var score_lbl = Label.new()
		score_lbl.text = "Skor: " + score
		score_lbl.custom_minimum_size = Vector2(220, 0)
		score_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		score_lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(score_lbl)

		# Label Max Combo
		var combo_lbl = Label.new()
		combo_lbl.text = "Combo: x" + combo
		combo_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		combo_lbl.add_theme_font_size_override("font_size", 26)
		row.add_child(combo_lbl)

		scores_container.add_child(row)


func _on_back_pressed() -> void:
	print("[Leaderboard] Kembali ke Main Menu...")
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
