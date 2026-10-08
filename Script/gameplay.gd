extends Node2D

# ==============================================================================
# ITEM & LANE SYSTEM
# ==============================================================================

var item_scene = preload("res://Scene/Items.tscn")

var lanes = [
	160.0,
	913.0,
	1491.0
]

# ==============================================================================
# SPAWN SYSTEM
# ==============================================================================

var spawn_timer := 0.0

# Awal game
var start_min_delay := 2.0
var start_max_delay := 3.0

# Akhir game
var end_min_delay := 1.0
var end_max_delay := 1.5

var next_spawn_delay := 0.0

# ==============================================================================
# SCORE & COMBO SYSTEM + FITUR P2W 2X MULTIPLIER (BIAYA: 3 KOIN)
# ==============================================================================

var score := 0
var max_score := 1000

# [P2W 2X MULTIPLIER]
const MULTIPLIER_COST := 3 # Biaya 3 koin dari database
var score_multiplier := 1
var is_multiplier_active := false

var combo := 0
var max_combo := 0

# ==============================================================================
# TIMER SYSTEM + FITUR P2W CONTINUE / EXTRA TIME (BIAYA: 5 KOIN)
# ==============================================================================

const EXTRA_TIME_COST := 5 # Biaya 5 koin dari database
var game_time_limit := 60.0
var game_timer := 0.0
var game_over := false

var continue_count := 0
var max_continue := 3

# ==============================================================================
# REFERENSI NODE UI
# ==============================================================================

@onready var score_label: Label = $ScoreLabel
@onready var combo_label: Label = $ComboLabel
@onready var timer_label: Label = $TimerLabel
@onready var coins_label: Label = $CoinsLabel

# UI Tombol 2x Multiplier
@onready var multiplier_button: Button = $MultiplierButton

# UI Popup Continue / Tambah Waktu
@onready var continue_popup: Control = $ContinuePopup
@onready var add_time_button: Button = $ContinuePopup/Panel/AddTimeButton
@onready var give_up_button: Button = $ContinuePopup/Panel/GiveUpButton
@onready var popup_description: Label = $ContinuePopup/Panel/Description


# ==============================================================================
# READY
# ==============================================================================

func _ready() -> void:
	randomize()

	update_score_label()
	update_combo_label()
	update_timer_label()
	update_coins_label(NetworkManager.current_coins)

	# Hubungkan sinyal update koin dari NetworkManager
	NetworkManager.coins_updated.connect(_on_coins_updated)

	# Jika mengetes langsung di scene gameplay (F6), otomatis login untuk mengambil data koin
	if NetworkManager.current_coins == 0:
		NetworkManager.login_player(NetworkManager.current_username)

	next_spawn_delay = randf_range(
		start_min_delay,
		start_max_delay
	)

	# Setup awal Continue Popup
	if continue_popup:
		continue_popup.hide()
		# PENTING: Process Mode Always agar tombol bisa diklik saat game di-pause
		continue_popup.process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_button_signals()


func _setup_button_signals() -> void:
	if multiplier_button:
		multiplier_button.pressed.connect(_on_multiplier_button_pressed)
	if add_time_button:
		add_time_button.pressed.connect(_on_add_time_button_pressed)
	if give_up_button:
		give_up_button.pressed.connect(_on_give_up_button_pressed)


func _on_coins_updated(new_coins: int) -> void:
	update_coins_label(new_coins)


func update_coins_label(amount: int) -> void:
	if coins_label:
		coins_label.text = "🪙 Koin: %d" % amount


# ==============================================================================
# GAME LOOP (TIMER & SPAWN WAVE)
# ==============================================================================

func _process(delta: float) -> void:
	if game_over:
		return

	# Timer game berjalan
	game_timer += delta
	update_timer_label()

	# Cek jika waktu permainan habis
	if game_timer >= game_time_limit:
		trigger_time_out()
		return

	# Spawn timer untuk memunculkan wave item terus-menerus
	spawn_timer += delta

	if spawn_timer >= next_spawn_delay:
		spawn_timer = 0.0

		var progress = clamp(
			game_timer / game_time_limit,
			0.0,
			1.0
		)

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

		spawn_wave()


# ==============================================================================
# SPAWN WAVE (3 ITEM SEKALIGUS: 1 BENAR, 2 SALAH)
# ==============================================================================

func spawn_wave() -> void:
	# Pilih secara acak jalur (lane) mana yang akan menjadi item BENAR
	var good_lane_idx = randi() % lanes.size()

	# Munculkan 3 item sekaligus di ketiga jalur jalan
	for i in range(lanes.size()):
		var item = item_scene.instantiate()
		item.target_x = lanes[i]
		item.position = Vector2(943, 482)
		
		# Tepat 1 item bernilai TRUE, dan 2 item lainnya bernilai FALSE
		item.is_good = (i == good_lane_idx)
		
		$Items.add_child(item)


# ==============================================================================
# FITUR P2W 1: BELI 2X POINT MULTIPLIER (BIAYA: 3 KOIN DARI DATABASE)
# ==============================================================================

func _on_multiplier_button_pressed() -> void:
	if is_multiplier_active:
		return

	# Cek apakah koin di database mencukupi (3 koin)
	if NetworkManager.current_coins < MULTIPLIER_COST:
		show_notice("Koin Tidak Cukup! Butuh %d Koin." % MULTIPLIER_COST, Color(1.0, 0.2, 0.2))
		return

	# Kunci tombol sementara proses pemotongan koin di database
	multiplier_button.disabled = true

	# Potong koin di database melalui API / Localhost
	NetworkManager.deduct_coins(
		"2x Point Multiplier",
		MULTIPLIER_COST,
		func(success: bool, remaining_coins: int, error_msg: String):
			if success:
				activate_double_points()
				show_notice("2X Point Aktif! (-3 🪙)", Color(1.0, 0.85, 0.1))
			else:
				# Buka kembali tombol jika gagal
				multiplier_button.disabled = false
				show_notice(error_msg, Color(1.0, 0.2, 0.2))
	)


func activate_double_points() -> void:
	is_multiplier_active = true
	score_multiplier = 2

	print("[P2W] 2x Point Multiplier berhasil diaktifkan!")

	if multiplier_button:
		multiplier_button.text = "⚡ 2X POINT (AKTIF)"
		multiplier_button.disabled = true


# ==============================================================================
# ADD SCORE & COMBO
# ==============================================================================

func add_score(amount: int) -> void:
	if game_over:
		return

	$BarangBener.play()

	combo += 1
	if combo > max_combo:
		max_combo = combo

	var combo_bonus := 0
	if combo >= 10:
		combo_bonus = 15
	elif combo >= 5:
		combo_bonus = 10
	elif combo >= 3:
		combo_bonus = 5

	# TOTAL POIN DIKALIKAN SCORE_MULTIPLIER (P2W)
	var final_score = (amount + combo_bonus) * score_multiplier

	score += final_score
	score = min(score, max_score)

	update_score_label()
	update_combo_label()


func subtract_score(amount: int) -> void:
	if game_over:
		return

	$BarangSalah.play()
	combo = 0
	update_combo_label()

	score -= amount
	score = max(score, 0)

	update_score_label()


# ==============================================================================
# FITUR P2W 2: TAMBAH WAKTU / CONTINUE SCREEN (BIAYA: 5 KOIN DARI DATABASE)
# ==============================================================================

func trigger_time_out() -> void:
	if continue_count >= max_continue or continue_popup == null:
		end_game()
		return

	# Reset pesan deskripsi dialog
	if popup_description:
		popup_description.text = "Waktu habis! Tambah waktu +30 detik seharga 5 Koin untuk lanjut bermain?"

	# Pause seluruh permainan
	get_tree().paused = true

	# Munculkan popup Tambah Waktu
	continue_popup.show()


# Pemain memilih untuk membeli waktu tambahan (+30s seharga 5 koin)
func _on_add_time_button_pressed() -> void:
	# Cek apakah koin pemain mencukupi (5 koin)
	if NetworkManager.current_coins < EXTRA_TIME_COST:
		if popup_description:
			popup_description.text = "❌ Koin tidak cukup! Butuh 5 Koin (Sisa Koin: %d)" % NetworkManager.current_coins
		return

	add_time_button.disabled = true

	# Potong koin di database via API / Localhost
	NetworkManager.deduct_coins(
		"Tambah Waktu (+30s)",
		EXTRA_TIME_COST,
		func(success: bool, remaining_coins: int, error_msg: String):
			add_time_button.disabled = false

			if success:
				continue_count += 1
				var extra_seconds := 30.0
				game_time_limit += extra_seconds

				print("[P2W] Tambah waktu sukses! (-5 🪙). Sisa koin: %d" % remaining_coins)

				if continue_popup:
					continue_popup.hide()

				# Lanjutkan game
				get_tree().paused = false

				# Langsung trigger wave berikutnya agar pemain langsung melihat gameplay bergerak kembali
				spawn_timer = next_spawn_delay - 0.2
				show_notice("Waktu +30s! (-5 🪙)", Color(0.2, 1.0, 0.3))
			else:
				if popup_description:
					popup_description.text = "❌ " + error_msg
	)


# Pemain memilih untuk menyerah / tidak menambah waktu
func _on_give_up_button_pressed() -> void:
	if continue_popup:
		continue_popup.hide()

	get_tree().paused = false
	end_game()


# ==============================================================================
# NOTIFIKASI FLOATING UI UNTUK FEEDBACK PEMBELIAN KOIN
# ==============================================================================

func show_notice(msg: String, color: Color) -> void:
	var label = Label.new()
	label.text = msg
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 26)
	label.z_index = 250
	label.position = Vector2(50, 155)

	add_child(label)

	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 25, 2.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(label.queue_free)


# ==============================================================================
# UPDATE UI LABELS
# ==============================================================================

func update_score_label() -> void:
	if score_label:
		score_label.text = " " + str(score)


func update_combo_label() -> void:
	if combo_label:
		combo_label.text = " Combo: x" + str(combo)


func update_timer_label() -> void:
	if timer_label:
		var time_left = max(0.0, game_time_limit - game_timer)
		timer_label.text = "Waktu: %d s" % int(ceil(time_left))


# ==============================================================================
# END GAME (KIRIM SKOR AKHIR KE DATABASE & PINDAH SCENE)
# ==============================================================================

func end_game() -> void:
	if game_over:
		return
	game_over = true

	get_tree().paused = false

	# Kirim skor akhir ke database
	var player_name = NetworkManager.current_username
	print("[Gameplay] Permainan berakhir! Menyimpan skor untuk: ", player_name)

	NetworkManager.submit_score(
		player_name,
		score,
		max_combo,
		is_multiplier_active
	)

	# Berpindah ke Scene bintang finish
	if score >= 300:
		get_tree().change_scene_to_file("res://Scene/bintang-3.tscn")
	elif score >= 150:
		get_tree().change_scene_to_file("res://Scene/bintang-2.tscn")
	else:
		get_tree().change_scene_to_file("res://Scene/bintang-1.tscn")


# ==============================================================================
# DEBUG CLICK
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Klik di posisi: ", event.position)
