<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\HttpException;
use Core\Request;

class GameController
{
    public function simpanSkor(Request $req, array $user): array
    {
        $skor  = (int) $req->input('skor', -1);
        $level = max(1, (int) $req->input('level', 1));
        $durasi = max(0, (int) $req->input('durasi_detik', 0));
        if ($skor < 0 || $skor > 100000) throw new HttpException('Skor tidak valid', 422);
        Database::pdo()->prepare('INSERT INTO skor_game (user_id, skor, level, durasi_detik) VALUES (?, ?, ?, ?)')
            ->execute([$user['id'], $skor, $level, $durasi]);
        return ['kode' => 201, 'pesan' => 'Skor tersimpan'];
    }

    /** 10 skor terbaik, satu skor terbaik per pengguna. */
    public function leaderboard(Request $req, array $user): array
    {
        $rows = Database::pdo()->query(
            'SELECT u.nama, MAX(s.skor) AS skor FROM skor_game s JOIN users u ON u.id = s.user_id
             GROUP BY s.user_id, u.nama ORDER BY skor DESC LIMIT 10'
        )->fetchAll();
        $rank = 0;
        return ['data' => array_map(fn ($r) => ['peringkat' => ++$rank, 'nama' => $r['nama'], 'skor' => (int) $r['skor']], $rows)];
    }
}
