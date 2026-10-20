<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\HttpException;
use Core\Request;
use Services\BlockchainService;

class PendaftaranController
{
    private const SELECT = 'SELECT d.id, d.status, d.total_idr, d.metode_bayar, d.created_at,
            d.program_id, d.jadwal_id,
            p.nama_program, p.jenjang, p.mapel, p.mode, p.durasi_minggu,
            b.id AS bimbel_id, b.nama AS bimbel_nama, b.alamat, b.kota,
            j.hari, j.jam_mulai, j.jam_selesai, j.tanggal_mulai
        FROM pendaftaran d
        JOIN program p ON p.id = d.program_id
        JOIN bimbel b  ON b.id = p.bimbel_id
        JOIN jadwal j  ON j.id = d.jadwal_id';

    public function store(Request $req, array $user): array
    {
        $programId = (int) $req->input('program_id', 0);
        $jadwalId  = (int) $req->input('jadwal_id', 0);
        $metode    = trim((string) $req->input('metode_bayar', 'transfer'));
        if (!in_array($metode, ['transfer', 'e-wallet', 'tunai'], true)) {
            throw new HttpException('Metode pembayaran tidak dikenal', 422);
        }

        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            // Kunci baris jadwal agar kuota tidak terlampaui jika dua orang daftar bersamaan.
            $st = $pdo->prepare('SELECT j.*, p.harga_idr FROM jadwal j JOIN program p ON p.id = j.program_id
                                 WHERE j.id = ? AND j.program_id = ? FOR UPDATE');
            $st->execute([$jadwalId, $programId]);
            $j = $st->fetch();
            if (!$j) throw new HttpException('Program atau jadwal tidak ditemukan', 404);
            if ((int) $j['terisi'] >= (int) $j['kuota']) throw new HttpException('Kuota jadwal ini sudah penuh', 409);

            $dup = $pdo->prepare("SELECT id FROM pendaftaran WHERE user_id = ? AND jadwal_id = ? AND status IN ('menunggu','aktif')");
            $dup->execute([$user['id'], $jadwalId]);
            if ($dup->fetch()) throw new HttpException('Kamu sudah terdaftar di jadwal ini', 409);

            $pdo->prepare('INSERT INTO pendaftaran (user_id, program_id, jadwal_id, total_idr, metode_bayar, status)
                           VALUES (?, ?, ?, ?, ?, "aktif")')
                ->execute([$user['id'], $programId, $jadwalId, $j['harga_idr'], $metode]);
            $id = (int) $pdo->lastInsertId();

            $pdo->prepare('UPDATE jadwal SET terisi = terisi + 1 WHERE id = ?')->execute([$jadwalId]);

            $block = BlockchainService::tambahBlock($pdo, $id, [
                'event' => 'DAFTAR', 'pendaftaran_id' => $id, 'user_id' => (int) $user['id'],
                'program_id' => $programId, 'jadwal_id' => $jadwalId, 'total_idr' => (int) $j['harga_idr'],
            ]);
            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }

        return ['kode' => 201, 'pesan' => 'Pendaftaran berhasil', 'data' => [
            'pendaftaran' => $this->ambil($id, (int) $user['id']),
            'block'       => $block,
        ]];
    }

    public function index(Request $req, array $user): array
    {
        $st = Database::pdo()->prepare(self::SELECT . ' WHERE d.user_id = ? ORDER BY d.created_at DESC, d.id DESC');
        $st->execute([$user['id']]);
        return ['data' => array_map([$this, 'format'], $st->fetchAll())];
    }

    public function show(Request $req, array $user): array
    {
        return ['data' => $this->ambil((int) $req->params['id'], (int) $user['id'])];
    }

    public function batal(Request $req, array $user): array
    {
        $id = (int) $req->params['id'];
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            $st = $pdo->prepare('SELECT * FROM pendaftaran WHERE id = ? AND user_id = ? FOR UPDATE');
            $st->execute([$id, $user['id']]);
            $d = $st->fetch();
            if (!$d) throw new HttpException('Pendaftaran tidak ditemukan', 404);
            if (!in_array($d['status'], ['menunggu', 'aktif'], true)) {
                throw new HttpException('Pendaftaran ini tidak bisa dibatalkan', 409);
            }
            $pdo->prepare('UPDATE pendaftaran SET status = "batal" WHERE id = ?')->execute([$id]);
            $pdo->prepare('UPDATE jadwal SET terisi = GREATEST(0, terisi - 1) WHERE id = ?')->execute([$d['jadwal_id']]);
            // Block lama tidak boleh diubah, jadi pembatalan dicatat sebagai block baru.
            BlockchainService::tambahBlock($pdo, $id, [
                'event' => 'BATAL', 'pendaftaran_id' => $id, 'user_id' => (int) $user['id'],
            ]);
            $pdo->commit();
        } catch (\Throwable $e) {
            $pdo->rollBack();
            throw $e;
        }
        return ['pesan' => 'Pendaftaran dibatalkan', 'data' => $this->ambil($id, (int) $user['id'])];
    }

    private function ambil(int $id, int $userId): array
    {
        $st = Database::pdo()->prepare(self::SELECT . ' WHERE d.id = ? AND d.user_id = ?');
        $st->execute([$id, $userId]);
        $r = $st->fetch();
        if (!$r) throw new HttpException('Pendaftaran tidak ditemukan', 404);
        return $this->format($r);
    }

    private function format(array $r): array
    {
        return [
            'id' => (int) $r['id'], 'status' => $r['status'], 'total_idr' => (int) $r['total_idr'],
            'metode_bayar' => $r['metode_bayar'], 'created_at' => $r['created_at'],
            'program' => [
                'id' => (int) $r['program_id'], 'nama_program' => $r['nama_program'], 'jenjang' => $r['jenjang'],
                'mapel' => $r['mapel'], 'mode' => $r['mode'], 'durasi_minggu' => (int) $r['durasi_minggu'],
            ],
            'bimbel' => ['id' => (int) $r['bimbel_id'], 'nama' => $r['bimbel_nama'], 'alamat' => $r['alamat'], 'kota' => $r['kota']],
            'jadwal' => [
                'id' => (int) $r['jadwal_id'], 'hari' => $r['hari'],
                'jam_mulai' => substr($r['jam_mulai'], 0, 5), 'jam_selesai' => substr($r['jam_selesai'], 0, 5),
                'tanggal_mulai' => $r['tanggal_mulai'],
            ],
        ];
    }
}
