extends Node2D


# =========================
# ITEM & LANE
# =========================

var item_scene = preload("res://Scene/Items.tscn")

var lanes = [
	-100.0,
	430.0,
	980.0
]


# =========================
# SPAWN SYSTEM
# =========================

var spawn_timer := 0.0

# Awal game
var start_min_delay := 2.0
var start_max_delay := 3.0

# Akhir game
var end_min_delay := 1.0
var end_max_delay := 1.5

var next_spawn_delay := 0.0

# 50% kemungkinan item baik, 50% item terlarang (Seimbang)
var good_chance := 0.6


# =========================
# SCORE SYSTEM
# =========================

var score := 0
var max_score := 999

var game_time_limit := 60.0
var game_timer := 0.0

var game_over := false


# =========================
# COMBO SYSTEM
# =========================

var combo := 0
var max_combo := 0


# =========================
# READY
# =========================

func _ready():

	randomize()

	update_score_label()
	update_combo_label()

	next_spawn_delay = randf_range(
		start_min_delay,
		start_max_delay
	)


# =========================
# GAME LOOP
# =========================

func _process(delta):

	if game_over:
		return

	# Timer game
	game_timer += delta

	# Jika waktu habis baru jalankan end_game()
	if game_timer >= game_time_limit:
		end_game()
		return

	# Spawn timer
	spawn_timer += delta

	if spawn_timer >= next_spawn_delay:

		spawn_timer = 0.0

		# Progress game dari 0 sampai 1
		var progress = clamp(
			game_timer / game_time_limit,
			0.0,
			1.0
		)

		# Spawn semakin cepat
		var current_min = lerp(
			start_min_delay,
			end_min_delay,
			progress
		)

		var current_max = lerp(
			start_max_delay,
			end_max_delay,
			progress
		)

		next_spawn_delay = randf_range(
			current_min,
			current_max
		)

		spawn_item()


# =========================
# SPAWN ITEM
# =========================

func spawn_item():

	# Pilih lane secara random
	var chosen_lane = randi() % lanes.size()

	# Membuat item
	var item = item_scene.instantiate()

	# Menentukan lane tujuan
	item.target_x = lanes[chosen_lane]

	# Posisi awal item
	item.position = Vector2(
		563,
		288
	)

	# Menentukan item baik / buruk (50:50)
	item.is_good = randf() < good_chance

	# Masukkan item ke node Items
	$Items.add_child(item)


# =========================
# ADD SCORE + COMBO
# =========================

func add_score(amount: int):

	if game_over:
		return

	# Tambah combo
	combo += 1

	# Simpan combo tertinggi
	if combo > max_combo:
		max_combo = combo

	# Bonus combo
	var combo_bonus := 0


	# COMBO X10
	if combo >= 10:

		combo_bonus = 15


	# COMBO X5
	elif combo >= 5:

		combo_bonus = 10


	# COMBO X3
	elif combo >= 3:

		combo_bonus = 5


	# Total poin
	var final_score = amount + combo_bonus

	# Tambah score
	score += final_score

	# Batasi score
	score = min(
		score,
		max_score
	)

	# Update UI
	update_score_label()
	update_combo_label()


# =========================
# BAD ITEM
# =========================

func subtract_score(amount: int):

	if game_over:
		return

	# Reset combo ke 0 saat menabrak item buruk
	combo = 0

	update_combo_label()

	# Kurangi score
	score -= amount

	# Tahan skor paling rendah di 0 (tidak minus)
	score = max(
		score,
		0
	)

	update_score_label()


# =========================
# UPDATE SCORE LABEL
# =========================

func update_score_label():
	$ScoreLabel.text = " " + str(score)


# =========================
# UPDATE COMBO LABEL
# =========================

func update_combo_label():
	$ComboLabel.text = "🔥 Combo: x" + str(combo)


# =========================
# END GAME
# =========================

func end_game():

	if game_over:
		return

	game_over = true


	# Penentuan kalah/menang baru diproses saat timer 60 detik selesai
	if score <= 0:

		get_tree().change_scene_to_file(
			"res://Scene/kalah.tscn"
		)


	# Score kurang dari 70
	elif score < 70:

		get_tree().change_scene_to_file(
			"res://Scene/coba_lagi.tscn"
		)


	# Score 70 atau lebih
	else:

		get_tree().change_scene_to_file(
			"res://Scene/menang.tscn"
		)


# =========================
# DEBUG CLICK
# =========================

func _unhandled_input(event):

	if event is InputEventMouseButton:

		if event.pressed:

			print(
				"Klik di posisi: ",
				event.position
			)
