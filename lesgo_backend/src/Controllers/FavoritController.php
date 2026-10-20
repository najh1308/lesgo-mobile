<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\HttpException;
use Core\Request;

class FavoritController
{
    public function index(Request $req, array $user): array
    {
        $st = Database::pdo()->prepare(
            'SELECT b.id, b.nama, b.alamat, b.kota, b.rating_avg, b.latitude, b.longitude,
                    MIN(p.harga_idr) AS harga_mulai,
                    GROUP_CONCAT(DISTINCT p.jenjang ORDER BY p.jenjang) AS jenjang
             FROM favorit f JOIN bimbel b ON b.id = f.bimbel_id JOIN program p ON p.bimbel_id = b.id
             WHERE f.user_id = ? GROUP BY b.id ORDER BY MAX(f.created_at) DESC'
        );
        $st->execute([$user['id']]);
        return ['data' => array_map(fn ($r) => [
            'id' => (int) $r['id'], 'nama' => $r['nama'], 'alamat' => $r['alamat'], 'kota' => $r['kota'],
            'latitude' => (float) $r['latitude'], 'longitude' => (float) $r['longitude'],
            'rating_avg' => (float) $r['rating_avg'], 'harga_mulai' => (int) $r['harga_mulai'],
            'jenjang' => explode(',', $r['jenjang']), 'is_favorit' => true,
        ], $st->fetchAll())];
    }

    public function tambah(Request $req, array $user): array
    {
        $id = (int) $req->params['bimbel_id'];
        $cek = Database::pdo()->prepare('SELECT id FROM bimbel WHERE id = ?');
        $cek->execute([$id]);
        if (!$cek->fetch()) throw new HttpException('Bimbel tidak ditemukan', 404);
        Database::pdo()->prepare('INSERT IGNORE INTO favorit (user_id, bimbel_id) VALUES (?, ?)')->execute([$user['id'], $id]);
        return ['kode' => 201, 'pesan' => 'Ditambahkan ke favorit'];
    }

    public function hapus(Request $req, array $user): array
    {
        Database::pdo()->prepare('DELETE FROM favorit WHERE user_id = ? AND bimbel_id = ?')
            ->execute([$user['id'], (int) $req->params['bimbel_id']]);
        return ['pesan' => 'Dihapus dari favorit'];
    }
}
