// Supabase Edge Function: tutor-ai
// Menerima { token, pesan: [{ role: 'user' | 'ai', teks }], lat?, lng? } dari aplikasi,
// memeriksa token login lewat fungsi api_me, mengambil data bimbel (untuk rekomendasi),
// lalu meneruskan pertanyaan ke LLM:
// Groq (secret GROQ_API_KEY) jika diisi, selain itu Google Gemini (secret GEMINI_API_KEY).
// API key hanya disimpan sebagai secret di Supabase, tidak pernah ada di aplikasi.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAKS_PESAN = 12;
const MAKS_KARAKTER = 2000;

const SYSTEM = `Kamu adalah "Geo", asisten AI di aplikasi GeoLearn, aplikasi untuk menemukan bimbingan belajar (bimbel) terdekat di Indonesia.
Penggunamu kebanyakan siswa SD, SMP, SMA, peserta UTBK, dan orang tua.

Yang bisa kamu bantu:
1. Materi pelajaran dan soal: jelaskan langkah demi langkah, lalu tulis jawaban akhirnya dengan jelas.
2. Pertanyaan umum (pengetahuan umum, sains sehari-hari, teknologi, bahasa, tips belajar, kampus dan jurusan, dan sebagainya): jawab dengan akurat dan ramah.
3. Rekomendasi bimbel: gunakan HANYA data bimbel di bagian "DATA BIMBEL GEOLEARN" di bawah. Pilih 1-3 yang paling cocok dengan jenjang, mata pelajaran, budget, mode (online/offline), atau jarak yang diminta. Sebutkan nama, kota, jarak (jika ada), harga mulai per bulan, dan rating, lalu alasan singkat kenapa cocok. Jika tidak ada yang cocok, katakan terus terang dan sarankan memakai fitur Cari di aplikasi. Jangan pernah mengarang nama bimbel, alamat, harga, atau nomor telepon.
4. Cara memakai aplikasi GeoLearn: tab Beranda, Cari (filter dan peta), Belajar (Tutor AI dan game Hitung Cepat), Aktivitas (pendaftaran, jadwal, favorit, riwayat terverifikasi), dan Profil.

Aturan:
- Jawab dalam Bahasa Indonesia yang sederhana dan mudah dipahami.
- Tulis dalam teks biasa. Jangan memakai LaTeX, tabel, atau simbol markdown seperti ** dan #. Gunakan daftar bernomor bila perlu.
- Jawaban ringkas: maksimal sekitar 200 kata kecuali pengguna meminta penjelasan panjang.
- Tolak dengan sopan permintaan yang berbahaya, tidak pantas untuk pelajar, atau melanggar hukum.
- Jika siswa meminta jawaban PR saja, tetap berikan cara pengerjaannya agar siswa paham.
- Jika kamu tidak yakin dengan sebuah fakta, katakan bahwa kamu tidak yakin.`;

function balas(status: number, pesan: string, data: unknown = null) {
  return new Response(
    JSON.stringify({ status: status < 400 ? "sukses" : "gagal", pesan, data }),
    { status, headers: { ...CORS, "Content-Type": "application/json" } },
  );
}

/** Kunci publik project untuk memanggil REST API (kunci baru atau legacy anon). */
function kunciPublik(): string {
  const baru = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (baru) {
    try {
      const daftar = JSON.parse(baru) as Record<string, string>;
      const pertama = Object.values(daftar)[0];
      if (pertama) return pertama;
    } catch (_) { /* pakai legacy */ }
  }
  return Deno.env.get("SUPABASE_ANON_KEY") ?? "";
}

type Pesan = { role: "user" | "ai"; teks: string };

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return balas(405, "Method tidak diizinkan");

  let body: { token?: string; pesan?: unknown; lat?: unknown; lng?: unknown };
  try {
    body = await req.json();
  } catch (_) {
    return balas(400, "Format permintaan tidak valid");
  }

  // 1. Periksa token login (login buatan sendiri, bukan Supabase Auth).
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const cek = await fetch(`${supabaseUrl}/rest/v1/rpc/api_me`, {
    method: "POST",
    headers: { apikey: kunciPublik(), "Content-Type": "application/json" },
    body: JSON.stringify({ p_token: body.token ?? "" }),
  });
  if (!cek.ok) return balas(401, "Sesi berakhir. Silakan login lagi.");
  const user = await cek.json() as { nama?: string };

  // 2. Rapikan riwayat percakapan.
  const mentah = Array.isArray(body.pesan) ? body.pesan.slice(-MAKS_PESAN) : [];
  let riwayat: Pesan[] = mentah
    .filter((p): p is Record<string, unknown> => typeof p === "object" && p !== null)
    .map((p) => ({
      role: p.role === "ai" ? "ai" as const : "user" as const,
      teks: String(p.teks ?? "").slice(0, MAKS_KARAKTER).trim(),
    }))
    .filter((p) => p.teks !== "");
  while (riwayat.length && riwayat[0].role === "ai") riwayat = riwayat.slice(1);
  if (!riwayat.length || riwayat[riwayat.length - 1].role !== "user") {
    return balas(422, "Pertanyaan tidak boleh kosong");
  }

  // 3. Ambil data bimbel dari database untuk bahan rekomendasi.
  const lat = typeof body.lat === "number" ? body.lat : null;
  const lng = typeof body.lng === "number" ? body.lng : null;
  const dataBimbel = await ambilDataBimbel(supabaseUrl, body.token ?? "", lat, lng);

  // 4. Panggil LLM: Groq jika GROQ_API_KEY diisi, selain itu Google Gemini.
  const sistem = `${SYSTEM}\n\nNama pengguna: ${user.nama ?? "-"}.\n` +
    `Lokasi pengguna: ${lat !== null ? "diketahui (jarak di bawah dihitung dari lokasinya)" : "tidak diketahui"}.\n\n` +
    `DATA BIMBEL GEOLEARN (${lat !== null ? "urut dari yang terdekat" : "urut dari rating tertinggi"}):\n${dataBimbel}`;
  const hasil = Deno.env.get("GROQ_API_KEY")
    ? await tanyaGroq(sistem, riwayat)
    : await tanyaGemini(sistem, riwayat);
  if (hasil instanceof Response) return hasil;
  const jawaban = hasil;
  return balas(200, "Berhasil", { jawaban });
});

// ---------- Data bimbel ----------

type ItemBimbel = {
  nama: string; kota: string; alamat: string; rating_avg: number; harga_mulai: number;
  jenjang: string[]; mapel: string; mode: string[]; jarak_km: number | null;
};

function rupiah(n: number): string {
  return "Rp" + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

/** Ringkasan daftar bimbel (maks. 20) dari fungsi api_bimbel_list. */
async function ambilDataBimbel(url: string, token: string, lat: number | null, lng: number | null): Promise<string> {
  try {
    const res = await fetch(`${url}/rest/v1/rpc/api_bimbel_list`, {
      method: "POST",
      headers: { apikey: kunciPublik(), "Content-Type": "application/json" },
      body: JSON.stringify({ p_token: token, p_lat: lat, p_lng: lng, p_per_page: 20 }),
    });
    if (!res.ok) return "(data bimbel sedang tidak tersedia)";
    const json = await res.json() as { items?: ItemBimbel[] };
    const items = json.items ?? [];
    if (!items.length) return "(belum ada data bimbel)";
    return items.map((b, i) =>
      `${i + 1}. ${b.nama} | ${b.alamat}, ${b.kota}` +
      (b.jarak_km != null ? ` | jarak ${String(b.jarak_km).replace(".", ",")} km` : "") +
      ` | jenjang ${(b.jenjang ?? []).join("/")} | mapel ${b.mapel}` +
      ` | ${(b.mode ?? []).join("/")} | mulai ${rupiah(b.harga_mulai)}/bulan | rating ${b.rating_avg}`
    ).join("\n");
  } catch (_) {
    return "(data bimbel sedang tidak tersedia)";
  }
}

// ---------- Penyedia LLM ----------

async function tanyaGemini(sistem: string, riwayat: Pesan[]): Promise<string | Response> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) return balas(503, "Tutor AI belum dikonfigurasi: tambahkan secret GEMINI_API_KEY atau GROQ_API_KEY di Supabase.");
  const model = Deno.env.get("GEMINI_MODEL") || "gemini-flash-latest";

  let res: Response;
  try {
    res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: sistem }] },
          contents: riwayat.map((p) => ({ role: p.role === "ai" ? "model" : "user", parts: [{ text: p.teks }] })),
          generationConfig: { temperature: 0.4, maxOutputTokens: 2048 },
        }),
      },
    );
  } catch (_) {
    return balas(502, "Layanan AI tidak dapat dihubungi. Coba lagi.");
  }

  // deno-lint-ignore no-explicit-any
  const json: any = await res.json().catch(() => null);
  if (res.status === 429) return balas(429, "Kuota Tutor AI sedang habis. Coba lagi beberapa saat lagi.");
  if (!res.ok || !json) {
    return balas(502, `Layanan AI menolak permintaan: ${json?.error?.message ?? `kode ${res.status}`}`);
  }
  const parts: Array<{ text?: string; thought?: boolean }> = json.candidates?.[0]?.content?.parts ?? [];
  const jawaban = parts.filter((p) => !p.thought && p.text).map((p) => p.text).join("").trim();
  if (!jawaban) {
    const alasan = json.candidates?.[0]?.finishReason ?? json.promptFeedback?.blockReason ?? "kosong";
    return balas(502, `Tutor AI tidak memberi jawaban (${alasan}). Coba ubah pertanyaannya.`);
  }
  return jawaban;
}

/** Model Groq yang dicoba berurutan. Jika satu model ditolak (tidak tersedia atau
 *  tidak diizinkan untuk akun ini), otomatis pindah ke model berikutnya. */
const MODEL_GROQ = [
  "llama-3.3-70b-versatile",
  "openai/gpt-oss-120b",
  "llama-3.1-8b-instant",
  "openai/gpt-oss-20b",
];

/** Groq memakai format API yang sama dengan OpenAI. */
async function tanyaGroq(sistem: string, riwayat: Pesan[]): Promise<string | Response> {
  const key = Deno.env.get("GROQ_API_KEY")!.trim();
  const pilihan = Deno.env.get("GROQ_MODEL")?.trim();
  const daftar = [...new Set([...(pilihan ? [pilihan] : []), ...MODEL_GROQ])];
  const messages = [
    { role: "system", content: sistem },
    ...riwayat.map((p) => ({ role: p.role === "ai" ? "assistant" : "user", content: p.teks })),
  ];

  let pesanGagal = "";
  for (const model of daftar) {
    const gptOss = model.startsWith("openai/gpt-oss");
    let res: Response;
    try {
      res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
        body: JSON.stringify({
          model,
          temperature: 0.4,
          max_tokens: gptOss ? 2048 : 1024,
          // Model gpt-oss "berpikir" dulu; dibuat singkat agar jawaban cepat.
          ...(gptOss ? { reasoning_effort: "low" } : {}),
          messages,
        }),
      });
    } catch (_) {
      return balas(502, "Layanan AI tidak dapat dihubungi. Coba lagi.");
    }

    // deno-lint-ignore no-explicit-any
    const json: any = await res.json().catch(() => null);
    if (res.status === 401) return balas(502, "API key Groq tidak valid. Periksa secret GROQ_API_KEY di Supabase.");
    if (res.status === 429) return balas(429, "Kuota Tutor AI sedang habis. Coba lagi beberapa saat lagi.");

    if (res.ok && json) {
      const jawaban = String(json.choices?.[0]?.message?.content ?? "").trim();
      if (jawaban) return jawaban;
      pesanGagal = "jawaban kosong";
      continue;
    }

    pesanGagal = json?.error?.message ?? `kode ${res.status}`;
    const kode = String(json?.error?.code ?? "");
    const masalahModel = res.status === 404 || res.status === 403 ||
      kode.includes("model") || /model/i.test(pesanGagal);
    if (!masalahModel) break; // error lain: tidak perlu mencoba model lain
    console.log(`Model ${model} ditolak (${pesanGagal}), mencoba model berikutnya.`);
  }
  return balas(502, `Layanan AI menolak permintaan: ${pesanGagal}`);
}
