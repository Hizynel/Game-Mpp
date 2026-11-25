extends Node

# ==============================================================================
# [PENGATURAN API: PIXEL 2 REALITY (P2R) GLOBAL API]
# ==============================================================================
# USE_PRODUCTION_API:
# - false = Menggunakan Localhost API Backend (http://127.0.0.1:3000/api)
# - true  = Menggunakan Server API Online Resmi P2R (https://api.pixel2reality.fun/api)
# ==============================================================================
const USE_PRODUCTION_API: bool = false
const LOCALHOST_BASE_URL: String = "http://127.0.0.1:3000/api"
const PRODUCTION_BASE_URL: String = "https://api.pixel2reality.fun/api"

# Identitas Game untuk Global Unified Leaderboard
const GAME_ID: String = "game_mpp"

# Biaya Masuk Permainan (1 - 500 Coins, rekomendasi default 50 Coins = Rp500)
const PLAY_GAME_COST: int = 50

# ==============================================================================
# DATA GLOBAL PEMAIN & KOIN
# ==============================================================================
var current_username: String = ""
var current_email: String = ""
var current_display_name: String = ""
var current_coins: int = 0
var is_logged_in: bool = false

# Sinyal sistem
signal login_completed(success: bool, message: String)
signal coins_updated(new_coins: int)
signal score_submitted(success: bool, response_data: Dictionary)
signal leaderboard_received(success: bool, data: Array)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_base_url() -> String:
	if USE_PRODUCTION_API:
		return PRODUCTION_BASE_URL
	return LOCALHOST_BASE_URL


# ==============================================================================
# 1. LOGIN USER / AKUN TEST P2R DENGAN EMAIL / USERNAME & PASSWORD
# ==============================================================================
func login_player(identifier: String, password: String = "", on_completed: Callable = Callable()) -> void:
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			var response_text = body.get_string_from_utf8()
			var parsed = JSON.parse_string(response_text)

			if (response_code == 200 or response_code == 201) and parsed is Dictionary and parsed.get("success", false) == true:
				current_username = parsed.get("username", identifier)
				current_email = parsed.get("email", "")
				current_display_name = parsed.get("displayName", current_username)
				current_coins = int(parsed.get("coins", 0))
				is_logged_in = true

				print("[NetworkManager] Login Berhasil: %s (%s) | Coins: %d" % [current_display_name, current_username, current_coins])
				coins_updated.emit(current_coins)
				login_completed.emit(true, "Login Berhasil")

				if on_completed.is_valid():
					on_completed.call(true, "Login Berhasil", current_coins)
			else:
				var err_msg = "Gagal login (Status: %d)" % response_code
				if parsed is Dictionary and parsed.has("message"):
					err_msg = str(parsed["message"])
				push_warning("[NetworkManager] " + err_msg)
				login_completed.emit(false, err_msg)

				if on_completed.is_valid():
					on_completed.call(false, err_msg, current_coins)
	)

	var payload = {
		"email": identifier if identifier.contains("@") else "",
		"username": identifier,
		"password": password
	}
	var json_string = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var target_url = get_base_url() + "/player/login"

	var err = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		http_request.queue_free()
		login_completed.emit(false, "Gagal mengirim permintaan HTTP")
		if on_completed.is_valid():
			on_completed.call(false, "Gagal inisiasi HTTP", current_coins)


# ==============================================================================
# 2. POTONG KOIN PEMAIN (SPEND COINS)
# Digunakan untuk:
# - Biaya Masuk Main Game (PLAY_GAME_COST = 50 Coins)
# - Fitur P2W Multiplier / Extra Time
# ==============================================================================
func deduct_coins(item_name: String, cost: int, on_result: Callable) -> void:
	# Pengecekan saldo client-side terlebih dahulu
	if current_coins < cost:
		var err_msg = "Koin tidak cukup! Butuh %d Coins, koin Anda: %d Coins" % [cost, current_coins]
		push_warning("[NetworkManager] " + err_msg)
		if on_result.is_valid():
			on_result.call(false, current_coins, err_msg)
		return

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200:
				var response_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(response_text)

				if parsed is Dictionary and parsed.get("success", false) == true:
					current_coins = int(parsed.get("remaining_coins", current_coins - cost))
					print("[NetworkManager] Koin dipotong: -%d Coins (%s) | Sisa: %d Coins" % [cost, item_name, current_coins])
					coins_updated.emit(current_coins)

					if on_result.is_valid():
						on_result.call(true, current_coins, "")
				else:
					var message = parsed.get("message", "Gagal memotong koin!") if parsed is Dictionary else "Gagal"
					push_warning("[NetworkManager] " + message)
					if on_result.is_valid():
						on_result.call(false, current_coins, message)
			else:
				var err_msg = "Gagal menghubungi server database (Error %d)" % response_code
				push_warning("[NetworkManager] " + err_msg)
				if on_result.is_valid():
					on_result.call(false, current_coins, err_msg)
	)

	var payload = {
		"username": current_username if current_username != "" else current_email,
		"game_id": GAME_ID,
		"item_name": item_name,
		"cost": cost
	}
	var json_string = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var target_url = get_base_url() + "/player/deduct_coins"

	var err = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		http_request.queue_free()
		if on_result.is_valid():
			on_result.call(false, current_coins, "Gagal inisiasi HTTP")


# ==============================================================================
# 3. KIRIM DATA SKOR AKHIR KE GLOBAL UNIFIED LEADERBOARD
# ==============================================================================
func submit_score(username: String, final_score: int, max_combo: int, used_multiplier: bool = false) -> void:
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				var response_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(response_text)
				print("[NetworkManager] Skor berhasil dikirim ke Leaderboard Global P2R!")
				score_submitted.emit(true, parsed if parsed is Dictionary else {})
			else:
				push_warning("[NetworkManager] Gagal simpan skor! Response: %d" % response_code)
				score_submitted.emit(false, {})
	)

	var player_identifier = username
	if player_identifier == "" and current_username != "":
		player_identifier = current_username

	var payload = {
		"username": player_identifier,
		"game_id": GAME_ID,
		"score": final_score,
		"max_combo": max_combo,
		"used_multiplier": used_multiplier,
		"created_at": Time.get_datetime_string_from_system()
	}

	var json_string = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var target_url = get_base_url() + "/score"

	var err = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		score_submitted.emit(false, {})
		http_request.queue_free()


# ==============================================================================
# 4. AMBIL GLOBAL UNIFIED LEADERBOARD
# ==============================================================================
func get_leaderboard() -> void:
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200:
				var response_text = body.get_string_from_utf8()
				var data = JSON.parse_string(response_text)
				leaderboard_received.emit(true, data if data is Array else [])
			else:
				leaderboard_received.emit(false, [])
	)

	var target_url = get_base_url() + "/leaderboard"
	var err = http_request.request(target_url)
	if err != OK:
		leaderboard_received.emit(false, [])
		http_request.queue_free()
