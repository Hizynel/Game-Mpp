#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backend"
cd "$DIR"

# Jika belum jalan di port 3000, jalankan node server.js
if ! ss -tulpn | grep -q ":3000 "; then
    nohup node server.js >> server.log 2>&1 &
    echo "Backend API P2R dijalankan di port 3000 (PID: $!)"
else
    echo "Backend API P2R sudah berjalan di port 3000."
fi
