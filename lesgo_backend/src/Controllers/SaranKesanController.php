<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\HttpException;
use Core\Request;

class SaranKesanController
{
    public function store(Request $req, array $user): array
    {
        $saran = trim((string) $req->input('saran', ''));
        $kesan = trim((string) $req->input('kesan', ''));
        $errors = [];
        if ($saran === '') $errors['saran'] = 'Saran wajib diisi';
        if ($kesan === '') $errors['kesan'] = 'Kesan wajib diisi';
        if ($errors) throw new HttpException('Data belum lengkap', 422, $errors);

        Database::pdo()->prepare('INSERT INTO saran_kesan (user_id, saran, kesan) VALUES (?, ?, ?)')
            ->execute([$user['id'], $saran, $kesan]);
        return ['kode' => 201, 'pesan' => 'Terima kasih, saran dan kesan terkirim'];
    }

    public function index(Request $req, array $user): array
    {
        $st = Database::pdo()->prepare('SELECT id, saran, kesan, created_at FROM saran_kesan WHERE user_id = ? ORDER BY created_at DESC');
        $st->execute([$user['id']]);
        return ['data' => $st->fetchAll()];
    }
}
