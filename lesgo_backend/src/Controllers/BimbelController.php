<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\HttpException;
use Core\Request;

class BimbelController
{
    /** Rumus haversine (km). Dipakai untuk LBS: jarak pengguna ke bimbel. */
    private const JARAK_SQL = '(6371 * ACOS(LEAST(1, COS(RADIANS(:lat1)) * COS(RADIANS(b.latitude))
        * COS(RADIANS(b.longitude) - RADIANS(:lng1)) + SIN(RADIANS(:lat2)) * SIN(RADIANS(b.latitude)))))';

    public function index(Request $req, array $user): array
    {
        $pdo = Database::pdo();
        $lat = $req->query('lat');
        $lng = $req->query('lng');
        $adaLokasi = is_numeric($lat) && is_numeric($lng);

        $select = 'b.id, b.nama, b.alamat, b.kota, b.latitude, b.longitude, b.foto, b.rating_avg,
                   MIN(p.harga_idr) AS harga_mulai,
                   GROUP_CONCAT(DISTINCT p.jenjang ORDER BY p.jenjang) AS jenjang,
                   GROUP_CONCAT(DISTINCT p.mapel SEPARATOR ", ") AS mapel,
                   GROUP_CONCAT(DISTINCT p.mode) AS mode,
                   (SELECT COUNT(*) FROM favorit f WHERE f.bimbel_id = b.id AND f.user_id = :uid) AS is_favorit';
        $bind = [':uid' => $user['id']];
        if ($adaLokasi) {
            $select .= ', ' . self::JARAK_SQL . ' AS jarak_km';
            $bind += [':lat1' => (float) $lat, ':lng1' => (float) $lng, ':lat2' => (float) $lat];
        }

        $where = ['1=1'];
        if (($q = $req->query('q')) !== null) {
            $where[] = '(b.nama LIKE :q1 OR b.kota LIKE :q2 OR b.alamat LIKE :q3 OR p.mapel LIKE :q4 OR p.nama_program LIKE :q5)';
            foreach (['q1', 'q2', 'q3', 'q4', 'q5'] as $k) $bind[":$k"] = "%$q%";
        }
        if (($j = $req->query('jenjang')) !== null) {
            $where[] = 'p.jenjang = :jenjang';
            $bind[':jenjang'] = strtoupper($j);
        }
        if (($m = $req->query('mapel')) !== null) {
            $where[] = 'p.mapel LIKE :mapel';
            $bind[':mapel'] = "%$m%";
        }
        if (($mode = $req->query('mode')) !== null) {
            $where[] = 'p.mode = :mode';
            $bind[':mode'] = strtolower($mode);
        }
        if (is_numeric($req->query('harga_min'))) {
            $where[] = 'p.harga_idr >= :hmin';
            $bind[':hmin'] = (int) $req->query('harga_min');
        }
        if (is_numeric($req->query('harga_max'))) {
            $where[] = 'p.harga_idr <= :hmax';
            $bind[':hmax'] = (int) $req->query('harga_max');
        }
        if (is_numeric($req->query('rating_min'))) {
            $where[] = 'b.rating_avg >= :rmin';
            $bind[':rmin'] = (float) $req->query('rating_min');
        }

        $having = '';
        if ($adaLokasi && is_numeric($req->query('radius'))) {
            $having = 'HAVING jarak_km <= :radius';
            $bind[':radius'] = (float) $req->query('radius');
        }

        $sort = $req->query('sort', $adaLokasi ? 'terdekat' : 'rating');
        $order = match ($sort) {
            'termurah' => 'harga_mulai ASC',
            'rating'   => 'b.rating_avg DESC, b.nama ASC',
            default    => $adaLokasi ? 'jarak_km ASC' : 'b.nama ASC',
        };

        $perPage = min(50, max(1, (int) $req->query('per_page', '20')));
        $page    = max(1, (int) $req->query('page', '1'));
        $offset  = ($page - 1) * $perPage;

        $sql = "SELECT $select FROM bimbel b JOIN program p ON p.bimbel_id = b.id
                WHERE " . implode(' AND ', $where) . " GROUP BY b.id $having
                ORDER BY $order LIMIT $perPage OFFSET $offset";
        $st = $pdo->prepare($sql);
        $st->execute($bind);

        $rows = array_map(fn ($r) => $this->format($r), $st->fetchAll());
        return ['data' => ['items' => $rows, 'page' => $page, 'per_page' => $perPage]];
    }

    public function show(Request $req, array $user): array
    {
        $pdo = Database::pdo();
        $id  = (int) $req->params['id'];
        $st  = $pdo->prepare('SELECT * FROM bimbel WHERE id = ?');
        $st->execute([$id]);
        $b = $st->fetch();
        if (!$b) throw new HttpException('Bimbel tidak ditemukan', 404);

        $lat = $req->query('lat');
        $lng = $req->query('lng');
        $jarak = null;
        if (is_numeric($lat) && is_numeric($lng)) {
            $jarak = $this->haversine((float) $lat, (float) $lng, (float) $b['latitude'], (float) $b['longitude']);
        }

        $fav = $pdo->prepare('SELECT COUNT(*) FROM favorit WHERE user_id = ? AND bimbel_id = ?');
        $fav->execute([$user['id'], $id]);
        $cnt = $pdo->prepare('SELECT COUNT(*) FROM review WHERE bimbel_id = ?');
        $cnt->execute([$id]);

        return ['data' => [
            'id'          => (int) $b['id'],
            'nama'        => $b['nama'],
            'alamat'      => $b['alamat'],
            'kota'        => $b['kota'],
            'latitude'    => (float) $b['latitude'],
            'longitude'   => (float) $b['longitude'],
            'deskripsi'   => $b['deskripsi'],
            'kontak'      => $b['kontak'],
            'jam_buka'    => $b['jam_buka'],
            'rating_avg'  => (float) $b['rating_avg'],
            'jumlah_review' => (int) $cnt->fetchColumn(),
            'jarak_km'    => $jarak !== null ? round($jarak, 1) : null,
            'is_favorit'  => (int) $fav->fetchColumn() > 0,
            'program'     => $this->programDenganJadwal($id),
        ]];
    }

    public function program(Request $req): array
    {
        return ['data' => $this->programDenganJadwal((int) $req->params['id'])];
    }

    public function jadwal(Request $req): array
    {
        return ['data' => $this->jadwalProgram((int) $req->params['id'])];
    }

    public function reviewList(Request $req): array
    {
        $st = Database::pdo()->prepare(
            'SELECT r.id, r.rating, r.komentar, r.created_at, u.nama
             FROM review r JOIN users u ON u.id = r.user_id
             WHERE r.bimbel_id = ? ORDER BY r.created_at DESC LIMIT 50'
        );
        $st->execute([(int) $req->params['id']]);
        return ['data' => array_map(fn ($r) => [
            'id' => (int) $r['id'], 'nama' => $r['nama'], 'rating' => (int) $r['rating'],
            'komentar' => $r['komentar'], 'created_at' => $r['created_at'],
        ], $st->fetchAll())];
    }

    public function reviewAdd(Request $req, array $user): array
    {
        $pdo = Database::pdo();
        $id = (int) $req->params['id'];
        $rating = (int) $req->input('rating', 0);
        $komentar = trim((string) $req->input('komentar', ''));
        if ($rating < 1 || $rating > 5) throw new HttpException('Rating harus 1 sampai 5', 422);

        // Review hanya boleh dari pengguna yang pernah mendaftar di bimbel ini.
        $cek = $pdo->prepare(
            "SELECT COUNT(*) FROM pendaftaran d JOIN program p ON p.id = d.program_id
             WHERE d.user_id = ? AND p.bimbel_id = ? AND d.status IN ('aktif','selesai')"
        );
        $cek->execute([$user['id'], $id]);
        if ((int) $cek->fetchColumn() === 0) {
            throw new HttpException('Review hanya untuk pengguna yang sudah mendaftar', 403);
        }

        $pdo->prepare(
            'INSERT INTO review (user_id, bimbel_id, rating, komentar) VALUES (?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE rating = VALUES(rating), komentar = VALUES(komentar)'
        )->execute([$user['id'], $id, $rating, $komentar]);

        $pdo->prepare('UPDATE bimbel SET rating_avg = (SELECT ROUND(AVG(rating), 1) FROM review WHERE bimbel_id = ?) WHERE id = ?')
            ->execute([$id, $id]);
        return ['kode' => 201, 'pesan' => 'Review tersimpan'];
    }

    // ---------- helper ----------

    private function programDenganJadwal(int $bimbelId): array
    {
        $st = Database::pdo()->prepare('SELECT * FROM program WHERE bimbel_id = ? ORDER BY harga_idr');
        $st->execute([$bimbelId]);
        return array_map(function ($p) {
            return [
                'id'            => (int) $p['id'],
                'nama_program'  => $p['nama_program'],
                'jenjang'       => $p['jenjang'],
                'mapel'         => $p['mapel'],
                'mode'          => $p['mode'],
                'harga_idr'     => (int) $p['harga_idr'],
                'durasi_minggu' => (int) $p['durasi_minggu'],
                'deskripsi'     => $p['deskripsi'],
                'jadwal'        => $this->jadwalProgram((int) $p['id']),
            ];
        }, $st->fetchAll());
    }

    private function jadwalProgram(int $programId): array
    {
        $st = Database::pdo()->prepare('SELECT * FROM jadwal WHERE program_id = ? ORDER BY tanggal_mulai, jam_mulai');
        $st->execute([$programId]);
        return array_map(fn ($j) => [
            'id'            => (int) $j['id'],
            'hari'          => $j['hari'],
            'jam_mulai'     => substr($j['jam_mulai'], 0, 5),     // WIB
            'jam_selesai'   => substr($j['jam_selesai'], 0, 5),   // WIB
            'tanggal_mulai' => $j['tanggal_mulai'],
            'kuota'         => (int) $j['kuota'],
            'terisi'        => (int) $j['terisi'],
            'sisa'          => max(0, (int) $j['kuota'] - (int) $j['terisi']),
        ], $st->fetchAll());
    }

    private function format(array $r): array
    {
        return [
            'id'          => (int) $r['id'],
            'nama'        => $r['nama'],
            'alamat'      => $r['alamat'],
            'kota'        => $r['kota'],
            'latitude'    => (float) $r['latitude'],
            'longitude'   => (float) $r['longitude'],
            'rating_avg'  => (float) $r['rating_avg'],
            'harga_mulai' => (int) $r['harga_mulai'],
            'jenjang'     => $r['jenjang'] === null ? [] : explode(',', $r['jenjang']),
            'mapel'       => $r['mapel'],
            'mode'        => $r['mode'] === null ? [] : explode(',', $r['mode']),
            'jarak_km'    => isset($r['jarak_km']) ? round((float) $r['jarak_km'], 1) : null,
            'is_favorit'  => (int) $r['is_favorit'] > 0,
        ];
    }

    private function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $a = sin(deg2rad($lat2 - $lat1) / 2) ** 2
           + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin(deg2rad($lng2 - $lng1) / 2) ** 2;
        return 6371 * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
