<?php
declare(strict_types=1);

namespace Controllers;

use Core\HttpException;
use Core\Request;
use Services\LlmService;

/** Tutor AI: aplikasi mengirim riwayat chat, server meneruskannya ke LLM. */
class AiController
{
    private const MAKS_PESAN = 12;     // riwayat yang ikut dikirim ke model
    private const MAKS_KARAKTER = 2000; // per pesan

    private const SYSTEM = <<<TXT
Kamu adalah "Tutor LesGo", tutor belajar yang ramah untuk siswa SD, SMP, SMA, dan peserta UTBK di Indonesia.
Aturan:
- Jawab dalam Bahasa Indonesia yang sederhana dan mudah dipahami sesuai jenjang siswa.
- Untuk soal hitungan, jelaskan langkah demi langkah lalu tulis jawaban akhirnya dengan jelas.
- Tulis dalam teks biasa. Jangan memakai LaTeX, tabel, atau simbol markdown seperti ** dan #. Gunakan daftar bernomor bila perlu.
- Jawaban ringkas: maksimal sekitar 200 kata kecuali siswa meminta penjelasan panjang.
- Jika pertanyaan tidak berkaitan dengan belajar atau sekolah, arahkan kembali dengan sopan ke topik belajar.
- Jika siswa meminta jawaban PR saja, tetap berikan cara pengerjaannya agar siswa paham.
TXT;

    public function tanya(Request $req, array $user): array
    {
        $pesan = $req->input('pesan');
        if (!is_array($pesan) || $pesan === []) {
            throw new HttpException('Pertanyaan tidak boleh kosong', 422);
        }

        $riwayat = [];
        foreach (array_slice($pesan, -self::MAKS_PESAN) as $p) {
            if (!is_array($p)) {
                continue;
            }
            $teks = trim(mb_substr((string) ($p['teks'] ?? ''), 0, self::MAKS_KARAKTER));
            if ($teks === '') {
                continue;
            }
            $riwayat[] = ['role' => ($p['role'] ?? '') === 'ai' ? 'ai' : 'user', 'teks' => $teks];
        }
        // Percakapan harus dimulai dan diakhiri oleh pesan pengguna.
        while ($riwayat && $riwayat[0]['role'] === 'ai') {
            array_shift($riwayat);
        }
        if (!$riwayat || end($riwayat)['role'] !== 'user') {
            throw new HttpException('Pertanyaan tidak boleh kosong', 422);
        }

        $sistem = self::SYSTEM . "\nNama siswa: " . $user['nama'] . '.';
        $jawaban = (new LlmService())->chat($sistem, $riwayat);
        return ['data' => ['jawaban' => $jawaban]];
    }
}
