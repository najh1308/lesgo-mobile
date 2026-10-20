<?php
declare(strict_types=1);

namespace Controllers;

use Core\Auth;
use Core\Database;
use Core\HttpException;
use Core\Request;

class AuthController
{
    public function register(Request $req): array
    {
        $nama  = trim((string) $req->input('nama', ''));
        $email = strtolower(trim((string) $req->input('email', '')));
        $noHp  = trim((string) $req->input('no_hp', ''));
        $pass  = (string) $req->input('password', '');

        $errors = [];
        if ($nama === '') $errors['nama'] = 'Nama wajib diisi';
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) $errors['email'] = 'Format email tidak valid';
        if (!preg_match('/^[0-9+]{9,15}$/', $noHp)) $errors['no_hp'] = 'Nomor HP tidak valid';
        if (strlen($pass) < 6) $errors['password'] = 'Password minimal 6 karakter';
        if ($errors) throw new HttpException('Data belum valid', 422, $errors);

        $pdo = Database::pdo();
        $cek = $pdo->prepare('SELECT id FROM users WHERE email = ?');
        $cek->execute([$email]);
        if ($cek->fetch()) {
            throw new HttpException('Email sudah terdaftar', 422, ['email' => 'Email sudah terdaftar']);
        }

        // Password di-hash dengan bcrypt, tidak pernah disimpan sebagai teks asli.
        $pdo->prepare('INSERT INTO users (nama, email, password_hash, no_hp) VALUES (?, ?, ?, ?)')
            ->execute([$nama, $email, password_hash($pass, PASSWORD_BCRYPT), $noHp]);

        return ['kode' => 201, 'pesan' => 'Akun berhasil dibuat. Silakan masuk.'];
    }

    public function login(Request $req): array
    {
        $email = strtolower(trim((string) $req->input('email', '')));
        $pass  = (string) $req->input('password', '');

        $st = Database::pdo()->prepare('SELECT * FROM users WHERE email = ?');
        $st->execute([$email]);
        $user = $st->fetch();

        if (!$user || !password_verify($pass, $user['password_hash'])) {
            throw new HttpException('Email atau password salah', 401);
        }
        $t = Auth::issueToken((int) $user['id']);
        return ['pesan' => 'Login berhasil', 'data' => [
            'token'      => $t['token'],
            'expired_at' => $t['expired_at'],
            'user'       => Auth::publicUser($user, $req),
        ]];
    }

    public function logout(Request $req): array
    {
        Auth::revoke($req);
        return ['pesan' => 'Berhasil keluar'];
    }

    public function me(Request $req, array $user): array
    {
        return ['data' => Auth::publicUser($user, $req)];
    }

    public function updateMe(Request $req, array $user): array
    {
        $nama = trim((string) $req->input('nama', $user['nama']));
        $noHp = trim((string) $req->input('no_hp', $user['no_hp']));
        $uang = strtoupper((string) $req->input('mata_uang_pref', $user['mata_uang_pref']));
        $zona = strtoupper((string) $req->input('zona_waktu_pref', $user['zona_waktu_pref']));

        if ($nama === '') throw new HttpException('Nama wajib diisi', 422);
        if (!in_array($uang, ['IDR', 'USD', 'EUR', 'JPY'], true)) throw new HttpException('Mata uang tidak didukung', 422);
        if (!in_array($zona, ['WIB', 'WITA', 'WIT', 'LONDON'], true)) throw new HttpException('Zona waktu tidak didukung', 422);

        Database::pdo()
            ->prepare('UPDATE users SET nama=?, no_hp=?, mata_uang_pref=?, zona_waktu_pref=? WHERE id=?')
            ->execute([$nama, $noHp, $uang, $zona, $user['id']]);

        $user = array_merge($user, ['nama' => $nama, 'no_hp' => $noHp, 'mata_uang_pref' => $uang, 'zona_waktu_pref' => $zona]);
        return ['pesan' => 'Profil diperbarui', 'data' => Auth::publicUser($user, $req)];
    }

    public function uploadFoto(Request $req, array $user): array
    {
        $f = $_FILES['foto'] ?? null;
        if (!$f || $f['error'] !== UPLOAD_ERR_OK) {
            throw new HttpException('File foto tidak ditemukan', 422);
        }
        if ($f['size'] > 2 * 1024 * 1024) {
            throw new HttpException('Ukuran foto maksimal 2 MB', 422);
        }
        $mime = (new \finfo(FILEINFO_MIME_TYPE))->file($f['tmp_name']);
        $ext  = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'][$mime] ?? null;
        if (!$ext) {
            throw new HttpException('Format foto harus JPG, PNG, atau WEBP', 422);
        }
        $dir = dirname(__DIR__, 2) . '/public/uploads';
        $nama = 'user_' . $user['id'] . '_' . time() . '.' . $ext;
        if (!move_uploaded_file($f['tmp_name'], "$dir/$nama")) {
            throw new HttpException('Gagal menyimpan foto', 500);
        }
        Database::pdo()->prepare('UPDATE users SET foto = ? WHERE id = ?')->execute(["uploads/$nama", $user['id']]);
        $user['foto'] = "uploads/$nama";
        return ['pesan' => 'Foto profil diperbarui', 'data' => Auth::publicUser($user, $req)];
    }

    public function ubahPassword(Request $req, array $user): array
    {
        $lama = (string) $req->input('password_lama', '');
        $baru = (string) $req->input('password_baru', '');
        if (!password_verify($lama, $user['password_hash'])) {
            throw new HttpException('Password lama salah', 422, ['password_lama' => 'Password lama salah']);
        }
        if (strlen($baru) < 6) {
            throw new HttpException('Password baru minimal 6 karakter', 422, ['password_baru' => 'Minimal 6 karakter']);
        }
        Database::pdo()->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($baru, PASSWORD_BCRYPT), $user['id']]);
        return ['pesan' => 'Password berhasil diubah'];
    }
}
