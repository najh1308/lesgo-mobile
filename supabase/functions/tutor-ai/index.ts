// Supabase Edge Function: tutor-ai
// Menerima { token, pesan: [{ role: 'user' | 'ai', teks }] } dari aplikasi,
// memeriksa token login lewat fungsi api_me, lalu meneruskan pertanyaan ke LLM:
// Groq (secret GROQ_API_KEY) jika diisi, selain itu Google Gemini (secret GEMINI_API_KEY).
// API key hanya disimpan sebagai secret di Supabase, tidak pernah ada di aplikasi.

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAKS_PESAN = 12;
const MAKS_KARAKTER = 2000;

const SYSTEM = `Kamu adalah "Tutor LesGo", tutor belajar yang ramah untuk siswa SD, SMP, SMA, dan peserta UTBK di Indonesia.
Aturan:
- Jawab dalam Bahasa Indonesia yang sederhana dan mudah dipahami sesuai jenjang siswa.
- Untuk soal hitungan, jelaskan langkah demi langkah lalu tulis jawaban akhirnya dengan jelas.
- Tulis dalam teks biasa. Jangan memakai LaTeX, tabel, atau simbol markdown seperti ** dan #. Gunakan daftar bernomor bila perlu.
- Jawaban ringkas: maksimal sekitar 200 kata kecuali siswa meminta penjelasan panjang.
- Jika pertanyaan tidak berkaitan dengan belajar atau sekolah, arahkan kembali dengan sopan ke topik belajar.
- Jika siswa meminta jawaban PR saja, tetap berikan cara pengerjaannya agar siswa paham.`;

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

  let body: { token?: string; pesan?: unknown };
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

  // 3. Panggil LLM: Groq jika GROQ_API_KEY diisi, selain itu Google Gemini.
  const sistem = `${SYSTEM}\nNama siswa: ${user.nama ?? "-"}.`;
  const hasil = Deno.env.get("GROQ_API_KEY")
    ? await tanyaGroq(sistem, riwayat)
    : await tanyaGemini(sistem, riwayat);
  if (hasil instanceof Response) return hasil;
  const jawaban = hasil;
  return balas(200, "Berhasil", { jawaban });
});

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

/** Groq memakai format API yang sama dengan OpenAI. */
async function tanyaGroq(sistem: string, riwayat: Pesan[]): Promise<string | Response> {
  const key = Deno.env.get("GROQ_API_KEY")!;
  const model = Deno.env.get("GROQ_MODEL") || "llama-3.3-70b-versatile";

  let res: Response;
  try {
    res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model,
        temperature: 0.4,
        max_tokens: 1024,
        messages: [
          { role: "system", content: sistem },
          ...riwayat.map((p) => ({ role: p.role === "ai" ? "assistant" : "user", content: p.teks })),
        ],
      }),
    });
  } catch (_) {
    return balas(502, "Layanan AI tidak dapat dihubungi. Coba lagi.");
  }

  // deno-lint-ignore no-explicit-any
  const json: any = await res.json().catch(() => null);
  if (res.status === 429) return balas(429, "Kuota Tutor AI sedang habis. Coba lagi beberapa saat lagi.");
  if (!res.ok || !json) {
    return balas(502, `Layanan AI menolak permintaan: ${json?.error?.message ?? `kode ${res.status}`}`);
  }
  const jawaban = String(json.choices?.[0]?.message?.content ?? "").trim();
  if (!jawaban) return balas(502, "Tutor AI tidak memberi jawaban. Coba lagi.");
  return jawaban;
}
