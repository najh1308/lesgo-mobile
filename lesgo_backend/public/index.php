<?php
declare(strict_types=1);

// Pintu masuk semua request API.
// Jalankan lokal:  php -S 0.0.0.0:8000 -t public public/index.php

// Jika memakai "php -S", biarkan file statis (misal foto di /uploads) dilayani langsung.
if (PHP_SAPI === 'cli-server') {
    $file = __DIR__ . parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
    if (is_file($file) && !str_ends_with($file, '.php')) {
        return false;
    }
}

require dirname(__DIR__) . '/src/bootstrap.php';

use Controllers\{AuthController, BimbelController, FavoritController, PendaftaranController,
    BlockchainController, KursController, GameController, SaranKesanController, AiController};
use Core\{HttpException, Request, Response, Router};

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Authorization, Content-Type');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$r = new Router();

// Autentikasi dan profil
$r->add('POST', '/api/register', [AuthController::class, 'register'], false);
$r->add('POST', '/api/login', [AuthController::class, 'login'], false);
$r->add('POST', '/api/logout', [AuthController::class, 'logout']);
$r->add('GET',  '/api/me', [AuthController::class, 'me']);
$r->add('PUT',  '/api/me', [AuthController::class, 'updateMe']);
$r->add('POST', '/api/me/foto', [AuthController::class, 'uploadFoto']);
$r->add('PUT',  '/api/me/password', [AuthController::class, 'ubahPassword']);

// Bimbel, program, jadwal, review
$r->add('GET',  '/api/bimbel', [BimbelController::class, 'index']);
$r->add('GET',  '/api/bimbel/{id}', [BimbelController::class, 'show']);
$r->add('GET',  '/api/bimbel/{id}/program', [BimbelController::class, 'program']);
$r->add('GET',  '/api/program/{id}/jadwal', [BimbelController::class, 'jadwal']);
$r->add('GET',  '/api/bimbel/{id}/review', [BimbelController::class, 'reviewList']);
$r->add('POST', '/api/bimbel/{id}/review', [BimbelController::class, 'reviewAdd']);

// Favorit
$r->add('GET',    '/api/favorit', [FavoritController::class, 'index']);
$r->add('POST',   '/api/favorit/{bimbel_id}', [FavoritController::class, 'tambah']);
$r->add('DELETE', '/api/favorit/{bimbel_id}', [FavoritController::class, 'hapus']);

// Pendaftaran
$r->add('POST', '/api/pendaftaran', [PendaftaranController::class, 'store']);
$r->add('GET',  '/api/pendaftaran', [PendaftaranController::class, 'index']);
$r->add('GET',  '/api/pendaftaran/{id}', [PendaftaranController::class, 'show']);
$r->add('PUT',  '/api/pendaftaran/{id}/batal', [PendaftaranController::class, 'batal']);

// Blockchain
$r->add('GET', '/api/blockchain', [BlockchainController::class, 'index']);
$r->add('GET', '/api/blockchain/validate', [BlockchainController::class, 'validasi']);

// Kurs, game, saran dan kesan
$r->add('GET',  '/api/kurs', [KursController::class, 'index'], false);
$r->add('POST', '/api/game/skor', [GameController::class, 'simpanSkor']);
$r->add('GET',  '/api/game/leaderboard', [GameController::class, 'leaderboard']);
$r->add('POST', '/api/saran-kesan', [SaranKesanController::class, 'store']);
$r->add('GET',  '/api/saran-kesan', [SaranKesanController::class, 'index']);

// Tutor AI (LLM)
$r->add('POST', '/api/ai/tanya', [AiController::class, 'tanya']);

try {
    $r->dispatch(new Request());
} catch (HttpException $e) {
    Response::json($e->status, $e->getMessage(), null, $e->errors);
} catch (Throwable $e) {
    $debug = env('APP_DEBUG', 'false') === 'true';
    Response::json(500, $debug ? $e->getMessage() : 'Terjadi kesalahan pada server');
}
