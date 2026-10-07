"""
==============================================================================
SERVER DATABASE LOCALHOST PYTHON (Testing Server untuk Game MPP)
==============================================================================
Server ini menyediakan API lokal lengkap dengan sistem koin & transaksi P2W:
- 2x Multiplier: 3 Koin
- Tambah Waktu: 5 Koin
==============================================================================
"""

import http.server
import socketserver
import json
import os
from datetime import datetime

PORT = 3000
DB_FILE = "database_scores.json"
PLAYERS_FILE = "database_players.json"

def load_json(filepath):
    if os.path.exists(filepath):
        try:
            with open(filepath, "r") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_json(filepath, data):
    with open(filepath, "w") as f:
        json.dump(data, f, indent=2)

class GameRequestHandler(http.server.BaseHTTPRequestHandler):

    def _set_headers(self, status_code=200):
        self.send_response(status_code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_OPTIONS(self):
        self._set_headers(200)

    def do_GET(self):
        if self.path == "/api/leaderboard":
            scores_data = load_json(DB_FILE)
            scores = scores_data if isinstance(scores_data, list) else []
            scores_sorted = sorted(scores, key=lambda x: x.get("score", 0), reverse=True)
            self._set_headers(200)
            self.wfile.write(json.dumps(scores_sorted[:10]).encode('utf-8'))

        elif self.path.startswith("/api/player/") and self.path.endswith("/coins"):
            username = self.path.split("/")[3]
            players = load_json(PLAYERS_FILE)
            player = players.get(username, {"coins": 20})
            self._set_headers(200)
            self.wfile.write(json.dumps({"success": True, "username": username, "coins": player.get("coins", 20)}).encode('utf-8'))

        elif self.path == "/api/health" or self.path == "/":
            self._set_headers(200)
            self.wfile.write(json.dumps({"status": "ok", "message": "Server Game MPP Python Aktif!"}).encode('utf-8'))
        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint tidak ditemukan"}).encode('utf-8'))

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            body = json.loads(post_data.decode('utf-8'))
        except Exception as e:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "Invalid JSON"}).encode('utf-8'))
            return

        # 1. LOGIN / AMBIL DATA KOIN PEMAIN
        if self.path == "/api/player/login":
            username = body.get("username", "Player")
            players = load_json(PLAYERS_FILE)
            if username not in players:
                players[username] = {"username": username, "coins": 20} # Modal awal 20 koin
                save_json(PLAYERS_FILE, players)
                print(f"[REGISTER] Pemain baru '{username}' dibuat dengan modal 20 koin.")
            else:
                print(f"[LOGIN] Pemain '{username}' login. Sisa koin: {players[username]['coins']}")

            self._set_headers(200)
            self.wfile.write(json.dumps({
                "success": True,
                "username": username,
                "coins": players[username]["coins"]
            }).encode('utf-8'))

        # 2. PENGURANGAN KOIN SAAT BELI ITEM P2W (3 koin untuk 2x, 5 koin untuk +waktu)
        elif self.path == "/api/player/deduct_coins":
            username = body.get("username", "Player")
            item_name = body.get("item_name", "Item P2W")
            cost = int(body.get("cost", 0))

            players = load_json(PLAYERS_FILE)
            if username not in players:
                players[username] = {"username": username, "coins": 20}

            current_coins = players[username]["coins"]

            if current_coins < cost:
                print(f"[P2W GAGAL] {username} mencoba beli '{item_name}' ({cost} koin), tapi koin hanya {current_coins}.")
                self._set_headers(200)
                self.wfile.write(json.dumps({
                    "success": False,
                    "message": f"Koin tidak cukup! Butuh {cost} koin, sisa koin Anda: {current_coins}",
                    "current_coins": current_coins
                }).encode('utf-8'))
            else:
                players[username]["coins"] -= cost
                remaining = players[username]["coins"]
                save_json(PLAYERS_FILE, players)

                print(f"[P2W SUKSES] {username} membeli '{item_name}' seharga {cost} koin. Sisa koin: {remaining}")
                self._set_headers(200)
                self.wfile.write(json.dumps({
                    "success": True,
                    "message": f"Berhasil membeli {item_name}!",
                    "cost": cost,
                    "remaining_coins": remaining
                }).encode('utf-8'))

        # 3. SIMPAN SKOR AKHIR
        elif self.path == "/api/score":
            scores = load_json(DB_FILE)
            if not isinstance(scores, list):
                scores = []
            scores.append(body)
            save_json(DB_FILE, scores)

            print(f"[SKOR DISIMPAN] {body.get('username')} | Skor: {body.get('score')} | Combo: {body.get('max_combo')}")
            self._set_headers(200)
            self.wfile.write(json.dumps({"success": True, "message": "Skor berhasil disimpan!"}).encode('utf-8'))

        else:
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Endpoint tidak ditemukan"}).encode('utf-8'))

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), GameRequestHandler) as httpd:
        print("=" * 65)
        print(f"🎮 SERVER PYTHON LOCALHOST AKTIF DI: http://127.0.0.1:{PORT}")
        print("  - POST /api/player/login         : Login/Cek Koin")
        print("  - POST /api/player/deduct_coins  : Potong Koin P2W")
        print("  - POST /api/score                : Simpan Skor")
        print("=" * 65)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer dihentikan.")
