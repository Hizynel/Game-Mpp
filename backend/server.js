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
const DB_CONFIG = {
    host: '127.0.0.1',
    user: 'root',
    password: 'database',
    database: 'game_godot',
    port: 3306
};

// Akun default P2R untuk testing
const DEFAULT_TEST_ACCOUNTS = [
    {
        email: 'saepudin.cihuy@pixel2reality.fun',
        username: 'saepudin.cihuy',
        displayName: 'Saepudin Cihuy',
        password: 'saepudin#cihuy-1945',
        coins: 1000
    },
    {
        email: 'kang.kerupuk@pixel2reality.fun',
        username: 'kang.kerupuk',
        displayName: 'Kang Kerupuk',
        password: 'kerupuk#renyah-1945',
        coins: 1000
    },
    {
        email: 'lord.geprek@pixel2reality.fun',
        username: 'lord.geprek',
        displayName: 'Lord Geprek',
        password: 'geprek#level99',
        coins: 1000
    },
    {
        email: 'masbro.kentang@pixel2reality.fun',
        username: 'masbro.kentang',
        displayName: 'Masbro Kentang',
        password: 'kentang#crispy-404',
        coins: 1000
    }
];

let dbPool = null;

// Fungsi inisialisasi koneksi & pembuatan tabel otomatis
async function initDatabase() {
    try {
        dbPool = mysql.createPool(DB_CONFIG);
        const connection = await dbPool.getConnection();
        console.log(`✅ Berhasil terhubung ke database MariaDB/MySQL: [${DB_CONFIG.database}]`);

        // 1. Buat tabel players dengan dukungan email & password
        await connection.query(`
            CREATE TABLE IF NOT EXISTS players (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(100) UNIQUE NOT NULL,
                email VARCHAR(150) UNIQUE DEFAULT NULL,
                password VARCHAR(255) DEFAULT NULL,
                display_name VARCHAR(100) DEFAULT NULL,
                coins INT NOT NULL DEFAULT 1000,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            );
        `);

        // Migration check jika kolom belum ada
        const [columns] = await connection.query(`SHOW COLUMNS FROM players;`);
        const colNames = columns.map(c => c.Field);
        if (!colNames.includes('email')) {
            await connection.query(`ALTER TABLE players ADD COLUMN email VARCHAR(150) UNIQUE DEFAULT NULL AFTER username;`);
        }
        if (!colNames.includes('password')) {
            await connection.query(`ALTER TABLE players ADD COLUMN password VARCHAR(255) DEFAULT NULL AFTER email;`);
        }
        if (!colNames.includes('display_name')) {
            await connection.query(`ALTER TABLE players ADD COLUMN display_name VARCHAR(100) DEFAULT NULL AFTER password;`);
        }

        // 2. Buat tabel scores (Leaderboard global gabungan)
        await connection.query(`
            CREATE TABLE IF NOT EXISTS scores (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(100) NOT NULL,
                game_id VARCHAR(50) DEFAULT 'game_mpp',
                score INT NOT NULL,
                max_combo INT NOT NULL DEFAULT 0,
                used_multiplier BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        const [scoreCols] = await connection.query(`SHOW COLUMNS FROM scores;`);
        const scoreColNames = scoreCols.map(c => c.Field);
        if (!scoreColNames.includes('game_id')) {
            await connection.query(`ALTER TABLE scores ADD COLUMN game_id VARCHAR(50) DEFAULT 'game_mpp' AFTER username;`);
        }

        // 3. Buat tabel coin_transactions
        await connection.query(`
            CREATE TABLE IF NOT EXISTS coin_transactions (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(100) NOT NULL,
                game_id VARCHAR(50) DEFAULT 'game_mpp',
                item_name VARCHAR(100) NOT NULL,
                cost INT NOT NULL,
                remaining_coins INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        // Seed default test accounts jika belum ada
        for (const acc of DEFAULT_TEST_ACCOUNTS) {
            const [existing] = await connection.query(
                'SELECT id FROM players WHERE email = ? OR username = ?',
                [acc.email, acc.username]
            );
            if (existing.length === 0) {
                await connection.query(
                    'INSERT INTO players (username, email, password, display_name, coins) VALUES (?, ?, ?, ?, ?)',
                    [acc.username, acc.email, acc.password, acc.displayName, acc.coins]
                );
                console.log(`[SEED] Akun P2R ditambahkan: ${acc.displayName} (${acc.email})`);
            }
        }

        connection.release();
        console.log("✅ Struktur tabel (players, scores, coin_transactions) sudah siap!");
    } catch (error) {
        console.error("❌ Gagal terhubung ke database MariaDB/MySQL:");
        console.error("   Pesan error:", error.message);
    }
}

// ==============================================================================
// 1. ENDPOINT: LOGIN PEMAIN (Mendukung Email/Password & Username P2R)
// ==============================================================================
app.post('/api/player/login', async (req, res) => {
    const { email, username, password } = req.body;
    const identifier = (email || username || '').trim();

    if (!identifier) {
        return res.status(400).json({ success: false, message: "Email atau Username wajib diisi" });
    }

    try {
        // Cek akun berdasarkan email atau username
        const [rows] = await dbPool.query(
            'SELECT * FROM players WHERE email = ? OR username = ?',
            [identifier, identifier]
        );

        if (rows.length > 0) {
            const player = rows[0];

            // Validasi password jika dikirimkan oleh client dan ada di DB
            if (password && player.password && player.password !== password.trim()) {
                console.log(`[LOGIN GAGAL] Password salah untuk: ${identifier}`);
                return res.status(401).json({ success: false, message: "Password salah!" });
            }

            console.log(`[LOGIN SUKSES] ${player.username} (${player.email || '-'}) masuk. Koin: ${player.coins}`);
            return res.json({
                success: true,
                id: player.id,
                username: player.username,
                email: player.email,
                displayName: player.display_name || player.username,
                coins: player.coins
            });
        } else {
            // Pemain baru otomatis terdaftar (Modal awal 1000 koin untuk testing P2R)
            const startingCoins = 1000;
            const isEmail = identifier.includes('@');
            const newEmail = isEmail ? identifier : null;
            const newUsername = isEmail ? identifier.split('@')[0] : identifier;
            const newDisplayName = newUsername;

            const [result] = await dbPool.query(
                'INSERT INTO players (username, email, password, display_name, coins) VALUES (?, ?, ?, ?, ?)',
                [newUsername, newEmail, password ? password.trim() : null, newDisplayName, startingCoins]
            );

            console.log(`[REGISTER] Pemain baru dibuat: ${newUsername} dengan modal ${startingCoins} koin.`);
            return res.json({
                success: true,
                id: result.insertId,
                username: newUsername,
                email: newEmail,
                displayName: newDisplayName,
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
        const [rows] = await dbPool.query('SELECT coins FROM players WHERE username = ? OR email = ?', [username, username]);
        if (rows.length > 0) {
            return res.json({ success: true, username, coins: rows[0].coins });
        }
        return res.status(404).json({ success: false, message: "Pemain tidak ditemukan" });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 3. ENDPOINT: PENGURANGAN KOIN (Spend Coins untuk Game Entrance / P2W)
// ==============================================================================
app.post('/api/player/deduct_coins', async (req, res) => {
    const { username, item_name, cost, game_id } = req.body;

    if (!username || cost === undefined || cost === null) {
        return res.status(400).json({ success: false, message: "Parameter tidak lengkap" });
    }

    try {
        const [rows] = await dbPool.query('SELECT coins FROM players WHERE username = ? OR email = ?', [username, username]);
        if (rows.length === 0) {
            return res.status(404).json({ success: false, message: "Pemain tidak ditemukan" });
        }

        const currentCoins = rows[0].coins;

        // Cek kecukupan saldo koin
        if (currentCoins < cost) {
            console.log(`[SPEND KOIN GAGAL] ${username} butuh ${cost} koin, tapi koin hanya ${currentCoins}.`);
            return res.status(400).json({
                success: false,
                message: `Koin tidak cukup! Butuh ${cost} koin, koin Anda: ${currentCoins}`,
                current_coins: currentCoins
            });
        }

        // Kurangi koin
        const remainingCoins = currentCoins - cost;
        await dbPool.query('UPDATE players SET coins = ? WHERE username = ? OR email = ?', [remainingCoins, username, username]);

        // Catat audit transaksi koin
        await dbPool.query(
            'INSERT INTO coin_transactions (username, game_id, item_name, cost, remaining_coins) VALUES (?, ?, ?, ?, ?)',
            [username, game_id || 'game_mpp', item_name || 'Game Entrance', cost, remainingCoins]
        );

        console.log(`[SPEND KOIN SUKSES] ${username} | Item: ${item_name} | Biaya: ${cost} | Sisa Koin: ${remainingCoins}`);

        return res.json({
            success: true,
            message: `Berhasil memotong ${cost} koin untuk ${item_name}!`,
            cost: cost,
            remaining_coins: remainingCoins
        });

    } catch (err) {
        console.error("Error pada /api/player/deduct_coins:", err.message);
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 4. ENDPOINT: SIMPAN SKOR AKHIR GAMEPLAY (Global Unified Leaderboard)
// ==============================================================================
app.post('/api/score', async (req, res) => {
    const { username, score, max_combo, used_multiplier, game_id } = req.body;

    try {
        await dbPool.query(
            'INSERT INTO scores (username, game_id, score, max_combo, used_multiplier) VALUES (?, ?, ?, ?, ?)',
            [username || 'Anonim', game_id || 'game_mpp', score || 0, max_combo || 0, !!used_multiplier]
        );

        console.log(`[SKOR DISIMPAN] ${username} (${game_id || 'game_mpp'}) | Skor: ${score} | Combo: ${max_combo}`);
        return res.json({ success: true, message: "Skor berhasil disimpan ke leaderboard!" });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// ==============================================================================
// 5. ENDPOINT: AMBIL GLOBAL LEADERBOARD SATU KESATUAN
// ==============================================================================
app.get('/api/leaderboard', async (req, res) => {
    const gameId = req.query.game_id;
    try {
        let query = 'SELECT s.username, p.display_name, s.game_id, s.score, s.max_combo, s.created_at FROM scores s LEFT JOIN players p ON (s.username = p.username OR s.username = p.email)';
        let params = [];

        if (gameId) {
            query += ' WHERE s.game_id = ?';
            params.push(gameId);
        }

        query += ' ORDER BY s.score DESC LIMIT 20';

        const [rows] = await dbPool.query(query, params);
        return res.json(rows);
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
});

// Jalankan Server
app.listen(PORT, '0.0.0.0', async () => {
    console.log("=================================================================");
    console.log(`🚀 API BACKEND GAME P2R BERJALAN DI: http://127.0.0.1:${PORT}`);
    console.log("=================================================================");
    await initDatabase();
});
