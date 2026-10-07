const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// ==============================================================================
// [PENGATURAN KONEKSI DATABASE MYSQL / MARIADB]
// ==============================================================================
// Sesuaikan username & password database komputer Anda di sini:
// ==============================================================================
const DB_CONFIG = {
    host: '127.0.0.1',
    user: 'root',         // Ganti dengan username MySQL/MariaDB Anda
    password: 'database', // Password MariaDB Anda
    database: 'game_godot',
    port: 3306
};

let dbPool = null;

// Fungsi inisialisasi koneksi & pembuatan tabel otomatis
async function initDatabase() {
    try {
        dbPool = mysql.createPool(DB_CONFIG);
        const connection = await dbPool.getConnection();
        console.log(`✅ Berhasil terhubung ke database MariaDB/MySQL: [${DB_CONFIG.database}]`);

        // Buat tabel jika masih kosongan
        await connection.query(`
            CREATE TABLE IF NOT EXISTS players (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                coins INT NOT NULL DEFAULT 20,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS scores (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) NOT NULL,
                score INT NOT NULL,
                max_combo INT NOT NULL DEFAULT 0,
                used_multiplier BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        await connection.query(`
            CREATE TABLE IF NOT EXISTS coin_transactions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) NOT NULL,
                item_name VARCHAR(100) NOT NULL,
                cost INT NOT NULL,
                remaining_coins INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        connection.release();
        console.log("✅ Struktur tabel (players, scores, coin_transactions) sudah siap!");
    } catch (error) {
        console.error("❌ Gagal terhubung ke database MariaDB/MySQL:");
        console.error("   Pesan error:", error.message);
        console.error("   👉 Pastikan service MariaDB/MySQL aktif dan sesuaikan 'password' di file backend/server.js!");
    }
}

// ==============================================================================
// 1. ENDPOINT: LOGIN / DAFTAR PEMAIN & AMBIL SALDO KOIN
// ==============================================================================
app.post('/api/player/login', async (req, res) => {
    const { username } = req.body;
    if (!username) {
        return res.status(400).json({ success: false, message: "Username wajib diisi" });
    }

    try {
        // Cek apakah pemain sudah ada
        const [rows] = await dbPool.query('SELECT * FROM players WHERE username = ?', [username]);

        if (rows.length > 0) {
            const player = rows[0];
            console.log(`[LOGIN] Pemain ${username} masuk. Koin: ${player.coins}`);
            return res.json({
                success: true,
                username: player.username,
                coins: player.coins
            });
        } else {
            // Pemain baru: berikan modal 20 koin
            const startingCoins = 20;
            await dbPool.query('INSERT INTO players (username, coins) VALUES (?, ?)', [username, startingCoins]);
            console.log(`[REGISTER] Pemain baru dibuat: ${username} dengan modal ${startingCoins} koin.`);
            return res.json({
                success: true,
                username: username,
                coins: startingCoins
            });
        }
    } catch (err) {
        console.error("Error pada /api/player/login:", err.message);
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 2. ENDPOINT: AMBIL SISA KOIN PEMAIN
// ==============================================================================
app.get('/api/player/:username/coins', async (req, res) => {
    const { username } = req.params;
    try {
        const [rows] = await dbPool.query('SELECT coins FROM players WHERE username = ?', [username]);
        if (rows.length > 0) {
            return res.json({ success: true, username, coins: rows[0].coins });
        }
        return res.status(404).json({ success: false, message: "Pemain tidak ditemukan" });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 3. ENDPOINT: PENGURANGAN KOIN SAAT BELI FITUR P2W (2x Point & Tambah Waktu)
// ==============================================================================
app.post('/api/player/deduct_coins', async (req, res) => {
    const { username, item_name, cost } = req.body;

    if (!username || cost === undefined || cost === null) {
        return res.status(400).json({ success: false, message: "Parameter tidak lengkap" });
    }

    try {
        // Ambil saldo koin pemain saat ini
        const [rows] = await dbPool.query('SELECT coins FROM players WHERE username = ?', [username]);
        if (rows.length === 0) {
            return res.status(404).json({ success: false, message: "Pemain tidak ditemukan" });
        }

        const currentCoins = rows[0].coins;

        // Cek kecukupan saldo koin
        if (currentCoins < cost) {
            console.log(`[P2W GAGAL] ${username} mencoba beli ${item_name} (${cost} koin), tapi koin hanya ${currentCoins}.`);
            return res.json({
                success: false,
                message: `Koin tidak cukup! Butuh ${cost} koin, sisa koin Anda: ${currentCoins}`,
                current_coins: currentCoins
            });
        }

        // Kurangi koin
        const remainingCoins = currentCoins - cost;
        await dbPool.query('UPDATE players SET coins = ? WHERE username = ?', [remainingCoins, username]);

        // Catat transaksi ke log audit
        await dbPool.query(
            'INSERT INTO coin_transactions (username, item_name, cost, remaining_coins) VALUES (?, ?, ?, ?)',
            [username, item_name || 'Item P2W', cost, remainingCoins]
        );

        console.log(`[P2W SUKSES] ${username} membeli ${item_name} seharga ${cost} koin. Sisa koin: ${remainingCoins}`);

        return res.json({
            success: true,
            message: `Berhasil membeli ${item_name}!`,
            cost: cost,
            remaining_coins: remainingCoins
        });

    } catch (err) {
        console.error("Error pada /api/player/deduct_coins:", err.message);
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 4. ENDPOINT: SIMPAN SKOR AKHIR GAMEPLAY
// ==============================================================================
app.post('/api/score', async (req, res) => {
    const { username, score, max_combo, used_multiplier } = req.body;

    try {
        await dbPool.query(
            'INSERT INTO scores (username, score, max_combo, used_multiplier) VALUES (?, ?, ?, ?)',
            [username || 'Anonim', score || 0, max_combo || 0, !!used_multiplier]
        );

        console.log(`[SKOR DISIMPAN] ${username} | Skor: ${score} | Combo: ${max_combo} | 2x: ${used_multiplier}`);
        return res.json({ success: true, message: "Skor berhasil disimpan ke database!" });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 5. ENDPOINT: AMBIL TOP LEADERBOARD
// ==============================================================================
app.get('/api/leaderboard', async (req, res) => {
    try {
        const [rows] = await dbPool.query('SELECT username, score, max_combo, created_at FROM scores ORDER BY score DESC LIMIT 10');
        return res.json(rows);
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// Jalankan Server
app.listen(PORT, '0.0.0.0', async () => {
    console.log("=================================================================");
    console.log(`🚀 API BACKEND GAME GODOT BERJALAN DI: http://127.0.0.1:${PORT}`);
    console.log("=================================================================");
    await initDatabase();
});
