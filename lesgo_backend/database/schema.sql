-- LesGo - skema database online (MySQL/MariaDB)
-- Jalankan file ini dulu, baru seed.sql.

CREATE DATABASE IF NOT EXISTS lesgo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE lesgo;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS saran_kesan, skor_game, blockchain_log, review, favorit,
  pendaftaran, jadwal, program, bimbel, auth_tokens, users;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama            VARCHAR(100) NOT NULL,
  email           VARCHAR(100) NOT NULL UNIQUE,
  password_hash   VARCHAR(255) NOT NULL,
  no_hp           VARCHAR(20)  NOT NULL,
  foto            VARCHAR(255) NULL,
  mata_uang_pref  VARCHAR(3)   NOT NULL DEFAULT 'IDR',
  zona_waktu_pref VARCHAR(10)  NOT NULL DEFAULT 'WIB',
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE auth_tokens (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,
  expired_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bimbel (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama       VARCHAR(150) NOT NULL,
  alamat     TEXT NOT NULL,
  kota       VARCHAR(80)  NOT NULL,
  latitude   DECIMAL(10,7) NOT NULL,
  longitude  DECIMAL(10,7) NOT NULL,
  deskripsi  TEXT NULL,
  kontak     VARCHAR(30) NULL,
  jam_buka   VARCHAR(50) NULL,
  foto       VARCHAR(255) NULL,
  rating_avg DECIMAL(2,1) NOT NULL DEFAULT 0.0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_bimbel_lokasi (latitude, longitude)
) ENGINE=InnoDB;

CREATE TABLE program (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bimbel_id     BIGINT UNSIGNED NOT NULL,
  nama_program  VARCHAR(150) NOT NULL,
  jenjang       ENUM('SD','SMP','SMA','UTBK') NOT NULL,
  mapel         VARCHAR(100) NOT NULL,
  mode          ENUM('offline','online') NOT NULL DEFAULT 'offline',
  harga_idr     INT UNSIGNED NOT NULL,
  durasi_minggu INT UNSIGNED NOT NULL DEFAULT 4,
  deskripsi     TEXT NULL,
  FOREIGN KEY (bimbel_id) REFERENCES bimbel(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE jadwal (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  program_id    BIGINT UNSIGNED NOT NULL,
  hari          VARCHAR(10) NOT NULL,
  jam_mulai     TIME NOT NULL,      -- disimpan dalam WIB
  jam_selesai   TIME NOT NULL,      -- disimpan dalam WIB
  tanggal_mulai DATE NOT NULL,
  kuota         INT UNSIGNED NOT NULL DEFAULT 20,
  terisi        INT UNSIGNED NOT NULL DEFAULT 0,
  FOREIGN KEY (program_id) REFERENCES program(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pendaftaran (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  program_id   BIGINT UNSIGNED NOT NULL,
  jadwal_id    BIGINT UNSIGNED NOT NULL,
  total_idr    INT UNSIGNED NOT NULL,
  metode_bayar VARCHAR(30) NOT NULL DEFAULT 'transfer',
  status       ENUM('menunggu','aktif','batal','selesai') NOT NULL DEFAULT 'aktif',
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id)    REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (program_id) REFERENCES program(id),
  FOREIGN KEY (jadwal_id)  REFERENCES jadwal(id)
) ENGINE=InnoDB;

-- Satu rantai block untuk seluruh sistem. Satu pendaftaran bisa punya lebih dari
-- satu block (DAFTAR lalu BATAL), karena block lama tidak boleh diubah.
CREATE TABLE blockchain_log (
  id             BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  block_index    INT UNSIGNED NOT NULL UNIQUE,
  pendaftaran_id BIGINT UNSIGNED NOT NULL,
  data           TEXT NOT NULL,
  prev_hash      CHAR(64) NOT NULL,
  hash           CHAR(64) NOT NULL,
  nonce          INT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME NOT NULL,
  FOREIGN KEY (pendaftaran_id) REFERENCES pendaftaran(id)
) ENGINE=InnoDB;

CREATE TABLE favorit (
  user_id    BIGINT UNSIGNED NOT NULL,
  bimbel_id  BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, bimbel_id),
  FOREIGN KEY (user_id)   REFERENCES users(id)  ON DELETE CASCADE,
  FOREIGN KEY (bimbel_id) REFERENCES bimbel(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE review (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED NOT NULL,
  bimbel_id  BIGINT UNSIGNED NOT NULL,
  rating     TINYINT UNSIGNED NOT NULL,
  komentar   TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_review (user_id, bimbel_id),
  FOREIGN KEY (user_id)   REFERENCES users(id)  ON DELETE CASCADE,
  FOREIGN KEY (bimbel_id) REFERENCES bimbel(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE skor_game (
  id           BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id      BIGINT UNSIGNED NOT NULL,
  skor         INT UNSIGNED NOT NULL,
  level        INT UNSIGNED NOT NULL DEFAULT 1,
  durasi_detik INT UNSIGNED NOT NULL DEFAULT 0,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE saran_kesan (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    BIGINT UNSIGNED NOT NULL,
  saran      TEXT NOT NULL,
  kesan      TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;
