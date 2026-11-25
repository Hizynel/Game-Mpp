extends Node

# ==============================================================================
# [PENGATURAN RESMI: PIXEL 2 REALITY (P2R) API GATE CHECK]
# ==============================================================================
# Dokumentasi & Kredensial Handoff:
# Base URL: https://pameran.devsaka.id/api/v1
# Game Slug: gate-check
# ==============================================================================

const API_BASE_URL: String = "https://pameran.devsaka.id/api/v1"
const GAME_SLUG: String = "gate-check"

# Runtime Credentials
const CLIENT_ID: String = "p2r_game_dwkpzk1twd32urh9"
const CLIENT_SECRET: String = "sec_L7EUUd00SWQblzpvIc3umtnYUBlsAPIlmaHU57Z1"

# Biaya Koin Permainan (Configured actions di P2R):
# - game_entry = 1 coin
# - extra_time = 2 coins
const PLAY_GAME_COST: int = 1

# ==============================================================================
# DATA RUNTIME PEMAIN, TOKEN & SESI
# ==============================================================================
var game_access_token: String = ""
var game_token_expires_at: float = 0.0

var player_bearer_token: String = ""
var current_username: String = ""
var current_email: String = ""
var current_display_name: String = ""
var current_coins: int = 0
var is_logged_in: bool = false

# Active Session Data
var current_session_id: String = ""
var current_session_token: String = ""

# Sinyal sistem
signal login_completed(success: bool, message: String)
signal coins_updated(new_coins: int)
signal score_submitted(success: bool, response_data: Dictionary)
signal leaderboard_received(success: bool, data: Array)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Dapatkan Game Access Token di awal
	ensure_game_token()


# ==============================================================================
# 1. GAME ACCESS TOKEN EXCHANGE (POST /games/{slug}/auth/token)
# ==============================================================================
func ensure_game_token(on_completed: Callable = Callable()) -> void:
	var current_time = Time.get_unix_time_from_system()
	if game_access_token != "" and current_time < (game_token_expires_at - 60):
		if on_completed.is_valid():
			on_completed.call(true)
		return

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				var res_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(res_text)
				if parsed is Dictionary and parsed.has("data"):
					var data = parsed["data"]
					game_access_token = data.get("access_token", "")
					var expires_in = data.get("expires_in", 900)
					game_token_expires_at = Time.get_unix_time_from_system() + expires_in
					print("[NetworkManager] Game Access Token resmi P2R didapatkan.")
					if on_completed.is_valid():
						on_completed.call(true)
					return

			push_warning("[NetworkManager] Gagal mendapatkan Game Access Token (Kode: %d)" % response_code)
			if on_completed.is_valid():
				on_completed.call(false)
	)

	var payload = {
		"client_id": CLIENT_ID,
		"client_secret": CLIENT_SECRET
	}
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	var url = API_BASE_URL + "/games/" + GAME_SLUG + "/auth/token"
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		if on_completed.is_valid():
			on_completed.call(false)


# ==============================================================================
# 2. LOGIN PEMAIN RESMI P2R (POST /auth/login)
# Mendapatkan Sanctum Bearer Token & Wallet Balance
# ==============================================================================
func login_player(identifier: String, password: String = "", on_completed: Callable = Callable()) -> void:
	ensure_game_token(func(token_ok: bool):
		_do_player_login(identifier, password, on_completed)
	)


func _do_player_login(identifier: String, password: String, on_completed: Callable) -> void:
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			var res_text = body.get_string_from_utf8()
			var parsed = JSON.parse_string(res_text)

			if response_code == 200 and parsed is Dictionary and parsed.has("data"):
				var data = parsed["data"]
				player_bearer_token = data.get("token", "")
				var user = data.get("user", {})
				current_display_name = user.get("name", identifier)
				current_email = user.get("email", identifier)
				current_username = current_email.split("@")[0]

				var wallet = user.get("wallet", {})
				current_coins = int(wallet.get("balance", 0))
				is_logged_in = true

				print("[NetworkManager] Login Berhasil: %s | Saldo: %d Coins" % [current_display_name, current_coins])
				coins_updated.emit(current_coins)
				login_completed.emit(true, "Login Berhasil")
				if on_completed.is_valid():
					on_completed.call(true, "Login Berhasil", current_coins)
			else:
				var err_msg = "Gagal login (Kode: %d)" % response_code
				if parsed is Dictionary and parsed.has("message") and str(parsed["message"]) != "":
					err_msg = str(parsed["message"])
				elif parsed is Dictionary and parsed.has("errors"):
					err_msg = str(parsed["errors"])

				push_warning("[NetworkManager] Login gagal: " + err_msg)
				login_completed.emit(false, err_msg)
				if on_completed.is_valid():
					on_completed.call(false, err_msg, 0)
	)

	var payload = {
		"email": identifier.strip_edges(),
		"password": password.strip_edges()
	}
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json"
	]
	var url = API_BASE_URL + "/auth/login"
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		if on_completed.is_valid():
			on_completed.call(false, "Gagal koneksi HTTP", 0)


# ==============================================================================
# LOGOUT PEMAIN (Hapus Token Sesi & Reset Data Akun)
# ==============================================================================
func logout_player(on_completed: Callable = Callable()) -> void:
	if player_bearer_token != "":
		var http_request = HTTPRequest.new()
		http_request.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(http_request)

		http_request.request_completed.connect(
			func(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
				http_request.queue_free()
				print("[NetworkManager] Logout API request selesai (Kode: %d)" % response_code)
		)

		var headers = [
			"Accept: application/json",
			"Authorization: Bearer " + player_bearer_token
		]
		var url = API_BASE_URL + "/auth/logout"
		http_request.request(url, headers, HTTPClient.METHOD_POST)

	# Reset semua data sesi lokal
	player_bearer_token = ""
	current_username = ""
	current_email = ""
	current_display_name = ""
	current_coins = 0
	is_logged_in = false
	current_session_id = ""
	current_session_token = ""

	print("[NetworkManager] Pemain berhasil logout. Data sesi telah dibersihkan.")
	coins_updated.emit(0)

	if on_completed.is_valid():
		on_completed.call(true)


# ==============================================================================
# 3. SPEND COIN RESMI (POST /games/{slug}/economy/spend)
# Action codes: 'game_entry' (1 coin), 'extra_time' (2 coins)
# ==============================================================================
func deduct_coins(action_code_or_item: String, cost: int, on_result: Callable) -> void:
	# Terjemahkan nama item ke action_code P2R
	var action_code = "game_entry"
	if action_code_or_item.contains("Waktu") or action_code_or_item == "extra_time":
		action_code = "extra_time"
	elif action_code_or_item.contains("game_entry") or action_code_or_item.contains("Mulai"):
		action_code = "game_entry"

	# Pastikan ada token
	if player_bearer_token == "":
		current_coins = max(0, current_coins - cost)
		coins_updated.emit(current_coins)
		if on_result.is_valid():
			on_result.call(true, current_coins, "")
		return

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			var res_text = body.get_string_from_utf8()
			var parsed = JSON.parse_string(res_text)

			if response_code == 200 and parsed is Dictionary and parsed.has("data"):
				var data = parsed["data"]
				var tx = data.get("transaction", {})
				current_coins = int(tx.get("balance_after", current_coins - cost))
				print("[NetworkManager] Koin dipotong P2R: action=%s, sisa=%d" % [action_code, current_coins])
				coins_updated.emit(current_coins)
				if on_result.is_valid():
					on_result.call(true, current_coins, "")
			else:
				var err_msg = "Koin tidak cukup atau transaksi gagal."
				if parsed is Dictionary and parsed.has("message") and str(parsed["message"]) != "":
					err_msg = str(parsed["message"])
				push_warning("[NetworkManager] Gagal potong koin: " + err_msg)
				if on_result.is_valid():
					on_result.call(false, current_coins, err_msg)
	)

	var payload = {
		"action_code": action_code
	}
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + player_bearer_token,
		"X-Game-Access-Token: " + game_access_token
	]
	var url = API_BASE_URL + "/games/" + GAME_SLUG + "/economy/spend"
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		if on_result.is_valid():
			on_result.call(false, current_coins, "Gagal request HTTP")


# ==============================================================================
# 4. GAME SESSIONS (START & COMPLETE SCORE)
# POST /games/{slug}/sessions/start
# POST /games/{slug}/sessions/{id}/complete
# ==============================================================================
func start_game_session(on_started: Callable = Callable()) -> void:
	if player_bearer_token == "" or game_access_token == "":
		if on_started.is_valid():
			on_started.call(true, "offline_session")
		return

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			var res_text = body.get_string_from_utf8()
			var parsed = JSON.parse_string(res_text)

			if response_code == 200 and parsed is Dictionary and parsed.has("data"):
				var data = parsed["data"]
				var session = data.get("session", {})
				current_session_id = session.get("id", "")
				current_session_token = data.get("session_token", "")
				print("[NetworkManager] P2R Game Session Aktif: " + current_session_id)
				if on_started.is_valid():
					on_started.call(true, current_session_id)
			else:
				push_warning("[NetworkManager] Gagal memulai sesi P2R (Kode: %d)" % response_code)
				if on_started.is_valid():
					on_started.call(false, "")
	)

	var uuid_str = "%x-%x" % [Time.get_ticks_msec(), randi()]
	var payload = {
		"idempotency_key": uuid_str
	}
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + player_bearer_token,
		"X-Game-Access-Token: " + game_access_token
	]
	var url = API_BASE_URL + "/games/" + GAME_SLUG + "/sessions/start"
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		if on_started.is_valid():
			on_started.call(false, "")


func submit_score(_username: String, final_score: int, max_combo: int, used_multiplier: bool = false) -> void:
	if current_session_id == "" or current_session_token == "":
		print("[NetworkManager] Tidak ada active session, submit score offline selesai.")
		score_submitted.emit(true, {})
		return

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				print("[NetworkManager] Skor berhasil dikirim ke P2R Leaderboard!")
				score_submitted.emit(true, {})
			else:
				push_warning("[NetworkManager] Gagal submit skor ke P2R (Kode: %d)" % response_code)
				score_submitted.emit(false, {})

			current_session_id = ""
			current_session_token = ""
	)

	var payload = {
		"session_token": current_session_token,
		"score": final_score,
		"data": {
			"score": final_score,
			"max_combo": max_combo,
			"multiplier_used": used_multiplier,
			"total_time": 60
		}
	}
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"Authorization: Bearer " + player_bearer_token,
		"X-Game-Access-Token: " + game_access_token
	]
	var url = API_BASE_URL + "/games/" + GAME_SLUG + "/sessions/" + current_session_id + "/complete"
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		http_request.queue_free()
		score_submitted.emit(false, {})


# ==============================================================================
# 5. GLOBAL LEADERBOARD RESMI P2R (GET /games/{slug}/leaderboard)
# ==============================================================================
func get_leaderboard() -> void:
	ensure_game_token(func(_ok: bool):
		_do_get_leaderboard()
	)


func _do_get_leaderboard() -> void:
	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200:
				var res_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(res_text)

				if parsed is Dictionary and parsed.has("data"):
					var lb_array = parsed["data"].get("leaderboard", [])
					print("[NetworkManager] Menerima %d entri Leaderboard resmi P2R" % lb_array.size())
					leaderboard_received.emit(true, lb_array)
					return

			leaderboard_received.emit(false, [])
	)

	var headers = [
		"Accept: application/json"
	]
	if game_access_token != "":
		headers.append("X-Game-Access-Token: " + game_access_token)
	if player_bearer_token != "":
		headers.append("Authorization: Bearer " + player_bearer_token)

	var url = API_BASE_URL + "/games/" + GAME_SLUG + "/leaderboard"
	var err = http_request.request(url, headers)
	if err != OK:
		http_request.queue_free()
		leaderboard_received.emit(false, [])
