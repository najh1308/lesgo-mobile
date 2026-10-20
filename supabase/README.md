# LesGo – Setup Supabase

Database online LesGo sekarang ada di Supabase (PostgreSQL), sehingga bisa diakses bersama dari HP mana pun tanpa laptop menyala. Database lokal di HP memakai Hive.

| Bagian | Teknologi | Isi |
|---|---|---|
| Database online | Supabase (PostgreSQL) | pengguna, bimbel, program, jadwal, pendaftaran, blockchain, favorit, review, skor game, saran-kesan |
| Web service | Fungsi RPC `api_*` + Edge Function `tutor-ai` | semua logika: login bcrypt, kuota, blockchain, jarak (LBS), Tutor AI |
| Web service luar | Frankfurter (kurs), Google Gemini (LLM), OpenStreetMap (peta) | |
| Database lokal | Hive | cache bimbel & kurs, pengaturan, riwayat chat AI, riwayat skor game |
| Session | flutter_secure_storage | token login terenkripsi |

## 1. Buat project Supabase

1. Buka https://supabase.com, lalu **Sign in** (bisa pakai akun GitHub).
2. Klik **New project**. Isi:
   - Name: `lesgo`
   - Database password: buat password lalu **simpan** (jarang dipakai, tapi jangan hilang).
   - Region: **Southeast Asia (Singapore)**, yang terdekat dengan Indonesia.
3. Klik **Create new project** dan tunggu sekitar 2 menit sampai selesai.

## 2. Buat tabel, fungsi, dan data contoh

1. Di menu kiri, buka **SQL Editor**, lalu klik **New query**.
2. Buka file `01_skema_dan_fungsi.sql`, salin seluruh isinya, tempel, lalu klik **Run**. Harus muncul "Success".
   Jika muncul peringatan "destructive operation", klik **Run this query**. File ini menghapus data lama sebelum membuat ulang.
3. Klik **New query** lagi. Lakukan hal yang sama untuk `02_data_contoh.sql`.
4. Cek di **Table Editor**: tabel `bimbel` berisi 16 baris.

Akun demo: `demo@lesgo.test` / `password123`

## 3. Sambungkan aplikasi

1. Buka **Project Settings** (ikon gerigi), lalu **API Keys**. Salin **Publishable key** (diawali `sb_publishable_`).
   Jika yang ada hanya tab *Legacy API keys*, salin **anon public** key.
2. Salin **Project URL** (bentuknya `https://xxxxxxxx.supabase.co`). Biasanya ada di **Project Settings > Data API**, atau di tombol **Connect** di bagian atas.
3. Buka `lib/core/config.dart`, lalu ganti dua nilai ini:
   ```dart
   defaultValue: 'https://ISI-PROJECT-ANDA.supabase.co'   // -> Project URL
   defaultValue: 'ISI_PUBLISHABLE_KEY_ANDA'               // -> Publishable key
   ```
   **Jangan** pakai *secret key* atau *service_role key* di aplikasi.

Publishable key aman berada di aplikasi karena semua tabel dikunci (Row Level Security). Aplikasi hanya bisa memanggil fungsi `api_*`, dan fungsi itu memeriksa token login sendiri.

## 4. Pasang Tutor AI (Edge Function)

1. Buat API key Gemini gratis di https://aistudio.google.com/apikey.
2. Di Supabase, buka **Edge Functions**, pilih **Secrets**, lalu tambahkan:
   - Key `GEMINI_API_KEY`, Value: API key dari langkah 1.
   - (opsional) Key `GEMINI_MODEL`, Value: `gemini-flash-latest`.
3. Buka **Edge Functions**, klik **Deploy a new function**, lalu pilih **Via Editor**.
   - Nama fungsi: `tutor-ai` (harus persis).
   - Hapus kode contoh, tempel isi `functions/tutor-ai/index.ts`, lalu klik **Deploy**.
4. Buka fungsi `tutor-ai`, lalu **Details/Settings**. **Matikan** opsi **Verify JWT** (Enforce JWT verification), kemudian simpan.
   Ini perlu karena aplikasi memakai login buatan sendiri; fungsi ini memeriksa token login sendiri.

## 5. Jalankan

```
flutter pub get
flutter run -d chrome
```
Di HP, cukup `flutter run` (tidak perlu `--dart-define` atau IP laptop lagi). HP cukup tersambung ke internet.

## Masalah umum

| Pesan | Penyebab |
|---|---|
| Alamat Supabase belum diisi | `lib/core/config.dart` belum diubah |
| Fungsi di Supabase belum dibuat | `01_skema_dan_fungsi.sql` belum dijalankan, atau baru saja dijalankan. Tunggu 10 detik lalu coba lagi |
| Email atau password salah | `02_data_contoh.sql` belum dijalankan |
| Tutor AI: Sesi berakhir / kode 401 | Verify JWT di fungsi `tutor-ai` belum dimatikan |
| Tutor AI belum dikonfigurasi | Secret `GEMINI_API_KEY` belum ditambahkan |
| Project tidak bisa diakses setelah lama tidak dipakai | Project gratis Supabase dijeda setelah sekitar 1 minggu tidak aktif. Buka dashboard lalu klik **Restore** |
