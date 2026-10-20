<?php
declare(strict_types=1);

namespace Controllers;

use Core\Database;
use Core\Request;
use Services\BlockchainService;

class BlockchainController
{
    /** Block yang berkaitan dengan pendaftaran milik pengguna. */
    public function index(Request $req, array $user): array
    {
        $st = Database::pdo()->prepare(
            'SELECT l.block_index, l.pendaftaran_id, l.data, l.prev_hash, l.hash, l.nonce, l.created_at
             FROM blockchain_log l JOIN pendaftaran d ON d.id = l.pendaftaran_id
             WHERE d.user_id = ? ORDER BY l.block_index DESC'
        );
        $st->execute([$user['id']]);
        return ['data' => array_map(fn ($b) => [
            'block_index' => (int) $b['block_index'], 'pendaftaran_id' => (int) $b['pendaftaran_id'],
            'event' => json_decode($b['data'], true)['event'] ?? '-',
            'prev_hash' => $b['prev_hash'], 'hash' => $b['hash'],
            'nonce' => (int) $b['nonce'], 'created_at' => $b['created_at'],
        ], $st->fetchAll())];
    }

    /** Validasi seluruh rantai (bukan hanya milik pengguna). */
    public function validasi(Request $req, array $user): array
    {
        $hasil = BlockchainService::validasi(Database::pdo());
        return [
            'pesan' => $hasil['valid'] ? 'Rantai valid. Data tidak pernah diubah.' : 'Rantai tidak valid. Ada block yang berubah.',
            'data'  => $hasil,
        ];
    }
}
