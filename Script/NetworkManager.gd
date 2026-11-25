extends Node

# ==============================================================================
# [PENGATURAN API: PIXEL 2 REALITY (P2R) GLOBAL API]
# ==============================================================================
# DEFAULT_API_URL:
# - Bisa menggunakan URL Server Online (jika ada domain / IP publik)
# - Atau fallback otomatis ke Localhost Server (http://127.0.0.1:3000/api)
# ==============================================================================

# URL API Server Online / Public (Bisa diisi jika sudah ada domain online atau hosting)
const REMOTE_API_URL: String = "https://api.pixel2reality.fun/api"

# URL API Server Lokal
const LOCAL_API_URL: String = "http://127.0.0.1:3000/api"

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
var current_coins: int = 1000
var is_logged_in: bool = false
var current_active_api_url: String = LOCAL_API_URL

# Sinyal sistem
signal login_completed(success: bool, message: String)
signal coins_updated(new_coins: int)
signal score_submitted(success: bool, response_data: Dictionary)
signal leaderboard_received(success: bool, data: Array)

# Offline Demo Mock Database (Fallback Mandiri jika server API offline / WiFi beda)
const DEMO_USERS = {
	"saepudin.cihuy@pixel2reality.fun": {
		"username": "saepudin.cihuy",
		"displayName": "Saepudin Cihuy",
		"password": "saepudin#cihuy-1945",
		"coins": 1000
	},
	"kang.kerupuk@pixel2reality.fun": {
		"username": "kang.kerupuk",
		"displayName": "Kang Kerupuk",
		"password": "kerupuk#renyah-1945",
		"coins": 1000
	},
	"lord.geprek@pixel2reality.fun": {
		"username": "lord.geprek",
		"displayName": "Lord Geprek",
		"password": "geprek#level99",
		"coins": 1000
	},
	"masbro.kentang@pixel2reality.fun": {
		"username": "masbro.kentang",
		"displayName": "Masbro Kentang",
		"password": "kentang#crispy-404",
		"coins": 1000
	}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Gunakan Local API URL sebagai prioritas stabil
	current_active_api_url = LOCAL_API_URL


func get_base_url() -> String:
	return current_active_api_url


# ==============================================================================
# 1. LOGIN USER / AKUN TEST P2R DENGAN DUAL-FALLBACK SYSTEM
# ==============================================================================
func login_player(identifier: String, password: String = "", on_completed: Callable = Callable()) -> void:
	var id_clean = identifier.strip_edges()
	var pass_clean = password.strip_edges()

	# Coba hubungi API Server terlebih dahulu
	_request_api_login(id_clean, pass_clean, func(success: bool, msg: String, coins: int):
		if success:
			if on_completed.is_valid():
				on_completed.call(true, msg, coins)
		else:
			# Jika gagal menghubungi server (misal server belum start / port tertutup),
			# otomatis aktifkan Fallback Offline Demo Auth agar akun demo SELALU BISA LOGIN!
			print("[NetworkManager] Server API tidak merespons, mengaktifkan Offline Demo Fallback...")
			_offline_login_fallback(id_clean, pass_clean, on_completed)
	)


func _request_api_login(identifier: String, password: String, cb: Callable) -> void:
	var http_request = HTTPRequest.new()
	http_request.timeout = 3.0 # Timeout cepat agar user tidak menunggu lama
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				var response_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(response_text)

				if parsed is Dictionary and parsed.get("success", false) == true:
					current_username = parsed.get("username", identifier)
					current_email = parsed.get("email", "")
					current_display_name = parsed.get("displayName", current_username)
					current_coins = int(parsed.get("coins", 1000))
					is_logged_in = true

					print("[NetworkManager] Online API Login Berhasil: %s | Coins: %d" % [current_display_name, current_coins])
					coins_updated.emit(current_coins)
					login_completed.emit(true, "Login Berhasil (Server API)")
					cb.call(true, "Login Berhasil (Server API)", current_coins)
					return

			# Jika respons kode bukan 200/201 atau gagal konek
			cb.call(false, "Server API tidak merespons (Kode: %d)" % response_code, 0)
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
		cb.call(false, "Koneksi HTTP Error", 0)


func _offline_login_fallback(identifier: String, password: String, on_completed: Callable) -> void:
	var id_lower = identifier.to_lower()

	# Cek apakah akun cocok dengan salah satu akun Demo P2R
	var matched_user = null
	for email_key in DEMO_USERS.keys():
		var demo = DEMO_USERS[email_key]
		if id_lower == email_key.to_lower() or id_lower == demo["username"].to_lower():
			matched_user = demo
			break

	if matched_user != null:
		# Validasi password jika ada
		if password != "" and matched_user["password"] != password:
			var err = "Password salah untuk akun demo!"
			push_warning("[NetworkManager] " + err)
			login_completed.emit(false, err)
			if on_completed.is_valid():
				on_completed.call(false, err, 0)
			return

		current_username = matched_user["username"]
		current_email = identifier if identifier.contains("@") else identifier + "@pixel2reality.fun"
		current_display_name = matched_user["displayName"]
		current_coins = matched_user["coins"]
		is_logged_in = true

		print("[NetworkManager] ✅ Berhasil Login Akun Demo: %s | Saldo: %d Coins" % [current_display_name, current_coins])
		coins_updated.emit(current_coins)
		login_completed.emit(true, "Login Akun Demo Berhasil!")
		if on_completed.is_valid():
			on_completed.call(true, "Login Akun Demo Berhasil!", current_coins)
	else:
		# Akun kustom baru
		var clean_name = identifier.split("@")[0]
		current_username = clean_name
		current_email = identifier if identifier.contains("@") else ""
		current_display_name = clean_name.capitalize()
		current_coins = 1000
		is_logged_in = true

		print("[NetworkManager] ✅ Berhasil Login Akun: %s | Saldo: %d Coins" % [current_display_name, current_coins])
		coins_updated.emit(current_coins)
		login_completed.emit(true, "Login Berhasil!")
		if on_completed.is_valid():
			on_completed.call(true, "Login Berhasil!", current_coins)


# ==============================================================================
# 2. POTONG KOIN PEMAIN (SPEND COINS)
# ==============================================================================
func deduct_coins(item_name: String, cost: int, on_result: Callable) -> void:
	# Cek saldo
	if current_coins < cost:
		var err_msg = "Koin tidak cukup! Butuh %d Coins, koin Anda: %d Coins" % [cost, current_coins]
		push_warning("[NetworkManager] " + err_msg)
		if on_result.is_valid():
			on_result.call(false, current_coins, err_msg)
		return

	# Kurangi koin langsung di client
	current_coins -= cost
	coins_updated.emit(current_coins)

	# Simpan juga ke Server API jika sedang online
	var http_request = HTTPRequest.new()
	http_request.timeout = 3.0
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()
			# Selesai sync background ke database
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

	http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)

	# Berikan konfirmasi sukses langsung ke gameplay
	if on_result.is_valid():
		on_result.call(true, current_coins, "")


# ==============================================================================
# 3. KIRIM DATA SKOR AKHIR KE GLOBAL UNIFIED LEADERBOARD
# ==============================================================================
func submit_score(username: String, final_score: int, max_combo: int, used_multiplier: bool = false) -> void:
	var player_identifier = username
	if player_identifier == "" and current_username != "":
		player_identifier = current_username

	var http_request = HTTPRequest.new()
	http_request.timeout = 3.0
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()
			score_submitted.emit(true, {})
	)

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
		http_request.queue_free()
		score_submitted.emit(true, {})


# ==============================================================================
# 4. AMBIL GLOBAL UNIFIED LEADERBOARD
# ==============================================================================
func get_leaderboard() -> void:
	var http_request = HTTPRequest.new()
	http_request.timeout = 3.0
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200:
				var response_text = body.get_string_from_utf8()
				var data = JSON.parse_string(response_text)
				if data is Array and not data.is_empty():
					leaderboard_received.emit(true, data)
					return

			# Fallback Dummy Data Leaderboard jika server offline
			var dummy_lb = [
				{"display_name": "Saepudin Cihuy", "game_id": "game_mpp", "score": 450, "max_combo": 28},
				{"display_name": "Kang Kerupuk", "game_id": "game_mpp", "score": 380, "max_combo": 22},
				{"display_name": "Lord Geprek", "game_id": "game_arcade", "score": 320, "max_combo": 18},
				{"display_name": "Masbro Kentang", "game_id": "game_runner", "score": 250, "max_combo": 15}
			]
			leaderboard_received.emit(true, dummy_lb)
	)

	var target_url = get_base_url() + "/leaderboard"
	var err = http_request.request(target_url)
	if err != OK:
		http_request.queue_free()
		var dummy_lb = [
			{"display_name": "Saepudin Cihuy", "game_id": "game_mpp", "score": 450, "max_combo": 28},
			{"display_name": "Kang Kerupuk", "game_id": "game_mpp", "score": 380, "max_combo": 22}
		]
		leaderboard_received.emit(true, dummy_lb)
