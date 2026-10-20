<?php
declare(strict_types=1);

namespace Services;

use PDO;

/**
 * Blockchain sederhana (terpusat di satu server) untuk mencatat pendaftaran.
 * Tiap block menyimpan hash block sebelumnya, jadi mengubah data lama akan
 * memutus rantai dan terdeteksi saat validasi.
 */
class BlockchainService
{
    public const GENESIS_PREV = '0000000000000000000000000000000000000000000000000000000000000000';
    public const DIFFICULTY   = '00';   // proof-of-work sederhana: hash harus diawali "00"

    public static function hitungHash(int $index, int $pendaftaranId, string $data, string $prev, string $waktu, int $nonce): string
    {
        return hash('sha256', implode('|', [$index, $pendaftaranId, $data, $prev, $waktu, $nonce]));
    }

    /** Tambah block baru. Harus dipanggil di dalam transaksi database. */
    public static function tambahBlock(PDO $pdo, int $pendaftaranId, array $data): array
    {
        $last = $pdo->query('SELECT block_index, hash FROM blockchain_log ORDER BY block_index DESC LIMIT 1 FOR UPDATE')->fetch();
        $index = $last ? (int) $last['block_index'] + 1 : 1;
        $prev  = $last ? $last['hash'] : self::GENESIS_PREV;
        $waktu = date('Y-m-d H:i:s');
        $json  = json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        $nonce = 0;
        do {
            $hash = self::hitungHash($index, $pendaftaranId, $json, $prev, $waktu, $nonce);
            $nonce++;
        } while (!str_starts_with($hash, self::DIFFICULTY));
        $nonce--;

        $pdo->prepare(
            'INSERT INTO blockchain_log (block_index, pendaftaran_id, data, prev_hash, hash, nonce, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)'
        )->execute([$index, $pendaftaranId, $json, $prev, $hash, $nonce, $waktu]);

        return ['block_index' => $index, 'hash' => $hash];
    }

    /** Cek seluruh rantai. Mengembalikan valid/tidak dan daftar block yang bermasalah. */
    public static function validasi(PDO $pdo): array
    {
        $rows = $pdo->query('SELECT * FROM blockchain_log ORDER BY block_index')->fetchAll();
        $prev = self::GENESIS_PREV;
        $rusak = [];
        $urutan = 1;

        foreach ($rows as $b) {
            $alasan = null;
            if ((int) $b['block_index'] !== $urutan) {
                $alasan = 'Nomor block tidak berurutan';
            } elseif ($b['prev_hash'] !== $prev) {
                $alasan = 'Hash sebelumnya tidak cocok';
            } else {
                $hitung = self::hitungHash((int) $b['block_index'], (int) $b['pendaftaran_id'], $b['data'], $b['prev_hash'], $b['created_at'], (int) $b['nonce']);
                if ($hitung !== $b['hash'] || !str_starts_with($hitung, self::DIFFICULTY)) {
                    $alasan = 'Isi block telah berubah';
                }
            }
            if ($alasan) {
                $rusak[] = ['block_index' => (int) $b['block_index'], 'alasan' => $alasan];
            }
            $prev = $b['hash'];
            $urutan++;
        }

        return [
            'valid'        => count($rusak) === 0,
            'total_block'  => count($rows),
            'block_rusak'  => $rusak,
        ];
    }
}
