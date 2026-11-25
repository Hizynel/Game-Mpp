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

# Deck item: 24 benar & 24 salah = 48 item (24 wave x 2 item)
var item_pool: Array[bool] = []
const JUMLAH_ITEM_PER_JENIS := 24

# ==============================================================================
# SPAWN SYSTEM
# ==============================================================================

var spawn_timer := 0.0

var start_min_delay := 2.4
var start_max_delay := 2.6

var end_min_delay := 2.1
var end_max_delay := 2.3

var next_spawn_delay := 0.0

# ==============================================================================
# SCORE & COMBO SYSTEM + FITUR P2W 2X MULTIPLIER (BIAYA: 150 KOIN)
# ==============================================================================

var score := 0
var max_score := 500

const MULTIPLIER_COST := 150
var score_multiplier := 1
var is_multiplier_active := false

var combo := 0
var max_combo := 0

# ==============================================================================
# TIMER SYSTEM + FITUR P2W CONTINUE / EXTRA TIME (BIAYA: 100 KOIN)
# ==============================================================================

const EXTRA_TIME_COST := 100
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

@onready var multiplier_button: Button = $MultiplierButton

@onready var continue_popup: Control = $ContinuePopup
@onready var add_time_button: Button = $ContinuePopup/Panel/AddTimeButton
@onready var give_up_button: Button = $ContinuePopup/Panel/GiveUpButton
@onready var popup_description: Label = $ContinuePopup/Panel/Description


# ==============================================================================
# READY
# ==============================================================================

func _ready() -> void:
	randomize()
	isi_deck_item(JUMLAH_ITEM_PER_JENIS)

	update_score_label()
	update_combo_label()
	update_timer_label()
	update_coins_label(NetworkManager.current_coins)

	NetworkManager.coins_updated.connect(_on_coins_updated)

	# Pastikan sesi P2R aktif agar skor akhir tercatat di leaderboard
	if NetworkManager.is_logged_in and NetworkManager.current_session_id == "":
		NetworkManager.start_game_session()

	next_spawn_delay = 0.5

	if continue_popup:
		continue_popup.hide()
		continue_popup.process_mode = Node.PROCESS_MODE_ALWAYS

	_setup_button_signals()


func isi_deck_item(jumlah_masing_masing: int) -> void:
	for i in range(jumlah_masing_masing):
		item_pool.append(true)
		item_pool.append(false)
	item_pool.shuffle()


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

	game_timer += delta
	update_timer_label()

	if game_timer >= game_time_limit:
		trigger_time_out()
		return

	spawn_timer += delta

	if spawn_timer >= next_spawn_delay:
		spawn_timer = 0.0

		var progress = clamp(game_timer / game_time_limit, 0.0, 1.0)
		var current_min = lerp(start_min_delay, end_min_delay, progress)
		var current_max = lerp(start_max_delay, end_max_delay, progress)

		next_spawn_delay = randf_range(current_min, current_max)
		spawn_wave()


# ==============================================================================
# SPAWN WAVE (2 ITEM ACAK DARI DECK KE 2 JALUR ACAK)
# ==============================================================================

func spawn_wave() -> void:
	if item_pool.is_empty():
		return

	var indeks_jalur = [0, 1, 2]
	indeks_jalur.shuffle()

	var jumlah_muncul = min(2, item_pool.size())
	for i in range(jumlah_muncul):
		var status_benar: bool = item_pool.pop_back()
		var item = item_scene.instantiate()
		item.target_x = lanes[indeks_jalur[i]]
		item.position = Vector2(943, 482)
		item.is_good = status_benar
		$Items.add_child(item)


# ==============================================================================
# FITUR P2W 1: BELI 2X POINT MULTIPLIER (ACTION: score_multiplier = 150 KOIN)
# ==============================================================================

func _on_multiplier_button_pressed() -> void:
	if is_multiplier_active:
		return

	if NetworkManager.current_coins < MULTIPLIER_COST:
		show_notice("Koin Tidak Cukup! Butuh %d Koin." % MULTIPLIER_COST, Color(1.0, 0.2, 0.2))
		return

	multiplier_button.disabled = true

	NetworkManager.deduct_coins(
		"score_multiplier",
		MULTIPLIER_COST,
		func(success: bool, remaining_coins: int, error_msg: String):
			if success:
				activate_double_points()
				show_notice("2X Point Aktif! (-%d 🪙)" % MULTIPLIER_COST, Color(1.0, 0.85, 0.1))
			else:
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
# FITUR P2W 2: TAMBAH WAKTU / CONTINUE SCREEN (ACTION: extra_time = 100 KOIN)
# ==============================================================================

func trigger_time_out() -> void:
	if continue_count >= max_continue or continue_popup == null:
		end_game()
		return

	if popup_description:
		popup_description.text = "Waktu habis! Tambah waktu +30 detik seharga %d Koin untuk lanjut bermain?" % EXTRA_TIME_COST

	get_tree().paused = true
	continue_popup.show()


func _on_add_time_button_pressed() -> void:
	if NetworkManager.current_coins < EXTRA_TIME_COST:
		if popup_description:
			popup_description.text = "❌ Koin tidak cukup! Butuh %d Koin (Sisa Koin: %d)" % [EXTRA_TIME_COST, NetworkManager.current_coins]
		return

	add_time_button.disabled = true

	NetworkManager.deduct_coins(
		"extra_time",
		EXTRA_TIME_COST,
		func(success: bool, remaining_coins: int, error_msg: String):
			add_time_button.disabled = false

			if success:
				continue_count += 1
				var extra_seconds := 30.0
				game_time_limit += extra_seconds
				isi_deck_item(12)

				print("[P2W] Tambah waktu sukses! (-%d 🪙). Sisa koin: %d" % [EXTRA_TIME_COST, remaining_coins])

				if continue_popup:
					continue_popup.hide()

				get_tree().paused = false
				spawn_timer = next_spawn_delay - 0.2
				show_notice("Waktu +30s! (-%d 🪙)" % EXTRA_TIME_COST, Color(0.2, 1.0, 0.3))
			else:
				if popup_description:
					popup_description.text = "❌ " + error_msg
	)


func _on_give_up_button_pressed() -> void:
	if continue_popup:
		continue_popup.hide()

	get_tree().paused = false
	end_game()


# ==============================================================================
# NOTIFIKASI FLOATING UI
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
# END GAME
# ==============================================================================

func end_game() -> void:
	if game_over:
		return
	game_over = true

	get_tree().paused = false

	var player_name = NetworkManager.current_username
	print("[Gameplay] Permainan berakhir! Menyimpan skor untuk: ", player_name)

	NetworkManager.submit_score(
		player_name,
		score,
		max_combo,
		is_multiplier_active
	)

	if score >= 350:
		get_tree().change_scene_to_file("res://Scene/bintang-3.tscn")
	elif score >= 180:
		get_tree().change_scene_to_file("res://Scene/bintang-2.tscn")
	else:
		get_tree().change_scene_to_file("res://Scene/bintang-1.tscn")


# ==============================================================================
# DEBUG CLICK
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("Klik di posisi: ", event.position)
