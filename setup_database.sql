-- ==============================================================================
-- STRUKTUR DATABASE: game_godot
-- ==============================================================================
-- Anda bisa menjalankan file SQL ini di:
-- 1. phpMyAdmin (menu Import atau tab SQL)
-- 2. DBeaver / HeidiSQL / MySQL Workbench
-- 3. Terminal: mariadb -u root -p game_godot < setup_database.sql
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS `game_godot`;
USE `game_godot`;

-- 1. Tabel data pemain dan saldo koin
CREATE TABLE IF NOT EXISTS `players` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) UNIQUE NOT NULL,
    `coins` INT NOT NULL DEFAULT 20, -- Saldo awal 20 koin untuk modal pemain
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. Tabel pencatatan skor (Leaderboard)
CREATE TABLE IF NOT EXISTS `scores` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL,
    `score` INT NOT NULL,
    `max_combo` INT NOT NULL DEFAULT 0,
    `used_multiplier` BOOLEAN DEFAULT FALSE,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabel log riwayat transaksi koin (Audit P2W)
CREATE TABLE IF NOT EXISTS `coin_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `username` VARCHAR(50) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `cost` INT NOT NULL,
    `remaining_coins` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
