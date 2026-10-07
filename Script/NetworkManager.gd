extends Node

# ==============================================================================
# [PENGATURAN API: UBAH DI SINI KETIKA SUDAH ADA API ONLINE / PRODUCTION]
# ==============================================================================
# 1. Ubah 'USE_PRODUCTION_API' menjadi 'true' ketika backend sudah online di hosting/VPS.
# 2. Ganti 'PRODUCTION_BASE_URL' dengan alamat domain server online Anda.
# ==============================================================================

# SETTING SWITCH:
# false = Menggunakan Localhost di komputer Anda
# true  = Menggunakan Server API Online di internet
const USE_PRODUCTION_API: bool = false

# URL ketika masih testing di localhost:
const LOCALHOST_BASE_URL: String = "http://127.0.0.1:3000/api"

# URL ketika sudah ada server API online (GANTI ALAMAT INI SAAT DEPLOY):
const PRODUCTION_BASE_URL: String = "https://api.domainkamu.com/api"

# ==============================================================================
# DATA GLOBAL PEMAIN & KOIN
# ==============================================================================

var current_username: String = "Player"
var current_coins: int = 0

# Sinyal untuk memberitahu UI / Scene lain saat koin berubah
signal coins_updated(new_coins: int)
signal score_submitted(success: bool, response_data: Dictionary)
signal leaderboard_received(success: bool, data: Array)


func _ready() -> void:
	# PENTING: Process Mode Always agar NetworkManager tidak ikut ter-pause saat game dipause
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_base_url() -> String:
	if USE_PRODUCTION_API:
		return PRODUCTION_BASE_URL
	return LOCALHOST_BASE_URL


# ==============================================================================
# 1. LOGIN / DAFTAR PEMAIN & AMBIL KOIN AWAL DARI DATABASE
# ==============================================================================

func login_player(username: String, on_completed: Callable = Callable()) -> void:
	current_username = username

	var http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				var response_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(response_text)
				if parsed is Dictionary and parsed.has("coins"):
					current_coins = int(parsed["coins"])
					print("[NetworkManager] Pemain login: %s | Saldo Koin: %d" % [current_username, current_coins])
					coins_updated.emit(current_coins)

				if on_completed.is_valid():
					on_completed.call(true, current_coins)
			else:
				push_warning("[NetworkManager] Gagal login/ambil koin. Kode: %d" % response_code)
				if on_completed.is_valid():
					on_completed.call(false, current_coins)
	)

	var payload = { "username": username }
	var json_string = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var target_url = get_base_url() + "/player/login"

	var err = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		http_request.queue_free()
		if on_completed.is_valid():
			on_completed.call(false, current_coins)


# ==============================================================================
# 2. POTONG KOIN PEMAIN SAAT MEMBELI FITUR P2W (Database Transaction)
# ==============================================================================
# Biaya:
# - 2x Multiplier = 3 Koin
# - Tambah Waktu  = 5 Koin
# ==============================================================================

func deduct_coins(item_name: String, cost: int, on_result: Callable) -> void:
	# Pengecekan cepat di client
	if current_coins < cost:
		var err_msg = "Koin tidak cukup! Butuh %d koin, koin Anda: %d" % [cost, current_coins]
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
					print("[NetworkManager] Transaksi sukses! Sisa koin di database: %d" % current_coins)
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
		"username": current_username,
		"item_name": item_name,
		"cost": cost
	}
	var json_string = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	var target_url = get_base_url() + "/player/deduct_coins"

	print("[NetworkManager] Membeli item '%s' seharga %d koin..." % [item_name, cost])
	var err = http_request.request(target_url, headers, HTTPClient.METHOD_POST, json_string)
	if err != OK:
		http_request.queue_free()
		if on_result.is_valid():
			on_result.call(false, current_coins, "Gagal inisiasi HTTP")


# ==============================================================================
# 3. KIRIM DATA SKOR AKHIR KE DATABASE
# ==============================================================================

func submit_score(username: String, final_score: int, max_combo: int, used_multiplier: bool = false) -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)

	http_request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
			http_request.queue_free()

			if response_code == 200 or response_code == 201:
				var response_text = body.get_string_from_utf8()
				var parsed = JSON.parse_string(response_text)
				print("[NetworkManager] Skor berhasil disimpan ke database!")
				score_submitted.emit(true, parsed if parsed is Dictionary else {})
			else:
				push_warning("[NetworkManager] Gagal simpan skor! Response: %d" % response_code)
				score_submitted.emit(false, {})
	)

	var payload = {
		"username": username,
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
# 4. AMBIL LEADERBOARD
# ==============================================================================

func get_leaderboard() -> void:
	var http_request = HTTPRequest.new()
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
