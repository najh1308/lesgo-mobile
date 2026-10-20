<?php
declare(strict_types=1);

namespace Core;

/** Token session: token acak dikirim ke klien, yang disimpan di DB hanya hash-nya. */
class Auth
{
    public static function issueToken(int $userId): array
    {
        $token = bin2hex(random_bytes(32));
        $days  = (int) env('TOKEN_TTL_DAYS', '7');
        $expired = date('Y-m-d H:i:s', time() + $days * 86400);
        Database::pdo()
            ->prepare('INSERT INTO auth_tokens (user_id, token_hash, expired_at) VALUES (?, ?, ?)')
            ->execute([$userId, hash('sha256', $token), $expired]);
        return ['token' => $token, 'expired_at' => $expired];
    }

    /** Validasi header Authorization lalu kembalikan data user. */
    public static function user(Request $req): array
    {
        $token = $req->bearerToken();
        if (!$token) {
            throw new HttpException('Token tidak ditemukan. Silakan login.', 401);
        }
        $st = Database::pdo()->prepare(
            'SELECT u.* FROM auth_tokens t JOIN users u ON u.id = t.user_id
             WHERE t.token_hash = ? AND t.expired_at > NOW()'
        );
        $st->execute([hash('sha256', $token)]);
        $user = $st->fetch();
        if (!$user) {
            throw new HttpException('Sesi berakhir. Silakan login lagi.', 401);
        }
        return $user;
    }

    public static function revoke(Request $req): void
    {
        $token = $req->bearerToken();
        if ($token) {
            Database::pdo()->prepare('DELETE FROM auth_tokens WHERE token_hash = ?')
                ->execute([hash('sha256', $token)]);
        }
    }

    /** Data user yang aman dikirim ke klien (tanpa hash password). */
    public static function publicUser(array $u, Request $req): array
    {
        return [
            'id'              => (int) $u['id'],
            'nama'            => $u['nama'],
            'email'           => $u['email'],
            'no_hp'           => $u['no_hp'],
            'foto_url'        => $u['foto'] ? $req->baseUrl() . '/' . $u['foto'] : null,
            'mata_uang_pref'  => $u['mata_uang_pref'],
            'zona_waktu_pref' => $u['zona_waktu_pref'],
        ];
    }
}
