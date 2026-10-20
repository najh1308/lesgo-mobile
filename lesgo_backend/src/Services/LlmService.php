<?php
declare(strict_types=1);

namespace Services;

use Core\HttpException;

/**
 * Pemanggil LLM. API key hanya disimpan di server (.env), tidak pernah dikirim ke aplikasi.
 *  - LLM_PROVIDER=gemini  : Google Gemini (ada kuota gratis lewat Google AI Studio)
 *  - LLM_PROVIDER=openai  : penyedia yang kompatibel dengan API OpenAI (Groq, OpenRouter, dll)
 */
class LlmService
{
    /**
     * @param string $system   instruksi peran untuk model
     * @param array  $riwayat  daftar ['role' => 'user'|'ai', 'teks' => '...'], diakhiri pesan user
     */
    public function chat(string $system, array $riwayat): string
    {
        $provider = strtolower(env('LLM_PROVIDER', 'gemini'));
        return $provider === 'openai'
            ? $this->openai($system, $riwayat)
            : $this->gemini($system, $riwayat);
    }

    private function gemini(string $system, array $riwayat): string
    {
        $key = env('GEMINI_API_KEY');
        if ($key === '') {
            throw new HttpException('Tutor AI belum dikonfigurasi: isi GEMINI_API_KEY di file .env server.', 503);
        }
        $model = env('GEMINI_MODEL', 'gemini-flash-latest');
        $url = 'https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode($model) . ':generateContent';

        $contents = array_map(fn ($p) => [
            'role'  => $p['role'] === 'ai' ? 'model' : 'user',
            'parts' => [['text' => $p['teks']]],
        ], $riwayat);

        $json = $this->post($url, ['x-goog-api-key: ' . $key], [
            'systemInstruction' => ['parts' => [['text' => $system]]],
            'contents'          => $contents,
            'generationConfig'  => ['temperature' => 0.4, 'maxOutputTokens' => 2048],
        ]);

        $teks = '';
        foreach ($json['candidates'][0]['content']['parts'] ?? [] as $part) {
            if (empty($part['thought']) && isset($part['text'])) {
                $teks .= $part['text'];
            }
        }
        if (trim($teks) === '') {
            $alasan = $json['candidates'][0]['finishReason'] ?? ($json['promptFeedback']['blockReason'] ?? 'kosong');
            throw new HttpException("Tutor AI tidak memberi jawaban ($alasan). Coba ubah pertanyaannya.", 502);
        }
        return trim($teks);
    }

    private function openai(string $system, array $riwayat): string
    {
        $key = env('LLM_API_KEY');
        $base = rtrim(env('LLM_BASE_URL', 'https://api.groq.com/openai/v1'), '/');
        $model = env('LLM_MODEL');
        if ($key === '' || $model === '') {
            throw new HttpException('Tutor AI belum dikonfigurasi: isi LLM_API_KEY dan LLM_MODEL di file .env server.', 503);
        }

        $messages = [['role' => 'system', 'content' => $system]];
        foreach ($riwayat as $p) {
            $messages[] = ['role' => $p['role'] === 'ai' ? 'assistant' : 'user', 'content' => $p['teks']];
        }

        $json = $this->post($base . '/chat/completions', ['Authorization: Bearer ' . $key], [
            'model'       => $model,
            'messages'    => $messages,
            'temperature' => 0.4,
            'max_tokens'  => 1024,
        ]);

        $teks = (string) ($json['choices'][0]['message']['content'] ?? '');
        if (trim($teks) === '') {
            throw new HttpException('Tutor AI tidak memberi jawaban. Coba lagi.', 502);
        }
        return trim($teks);
    }

    private function post(string $url, array $headers, array $body): array
    {
        $ctx = stream_context_create(['http' => [
            'method'        => 'POST',
            'header'        => implode("\r\n", array_merge(['Content-Type: application/json'], $headers)),
            'content'       => json_encode($body, JSON_UNESCAPED_UNICODE),
            'timeout'       => 40,
            'ignore_errors' => true, // agar isi pesan error dari penyedia tetap terbaca
        ]]);
        $res = @file_get_contents($url, false, $ctx);

        $responseHeaders = function_exists('http_get_last_response_headers')
            ? (http_get_last_response_headers() ?? [])
            : ($http_response_header ?? []);
        $status = 0;
        if (isset($responseHeaders[0]) && preg_match('#\s(\d{3})#', $responseHeaders[0], $m)) {
            $status = (int) $m[1];
        }

        if ($res === false || $status === 0) {
            throw new HttpException('Server tidak dapat menghubungi layanan AI. Periksa internet server.', 502);
        }
        $json = json_decode($res, true);
        if ($status === 429) {
            throw new HttpException('Kuota Tutor AI sedang habis. Coba lagi beberapa saat lagi.', 429);
        }
        if ($status >= 400 || !is_array($json)) {
            $pesan = is_array($json) ? ($json['error']['message'] ?? "kode $status") : "kode $status";
            throw new HttpException('Layanan AI menolak permintaan: ' . $pesan, 502);
        }
        return $json;
    }
}
