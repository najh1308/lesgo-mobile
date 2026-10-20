<?php
declare(strict_types=1);

namespace Core;

class Request
{
    public array $params = [];   // parameter path, misal {id}
    private ?array $json = null;

    public function method(): string
    {
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    }

    public function path(): string
    {
        $path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        return rtrim($path, '/') ?: '/';
    }

    public function query(string $key, ?string $default = null): ?string
    {
        $v = $_GET[$key] ?? null;
        return ($v === null || $v === '') ? $default : (string) $v;
    }

    /** Isi body: JSON jika ada, selain itu form biasa. */
    public function body(): array
    {
        if ($this->json === null) {
            $raw = file_get_contents('php://input') ?: '';
            $decoded = json_decode($raw, true);
            $this->json = is_array($decoded) ? $decoded : $_POST;
        }
        return $this->json;
    }

    public function input(string $key, mixed $default = null): mixed
    {
        return $this->body()[$key] ?? $default;
    }

    public function bearerToken(): ?string
    {
        $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if ($h === '' && function_exists('getallheaders')) {
            foreach (getallheaders() as $k => $v) {
                if (strtolower($k) === 'authorization') {
                    $h = $v;
                }
            }
        }
        return preg_match('/^Bearer\s+(.+)$/i', $h, $m) ? trim($m[1]) : null;
    }

    public function baseUrl(): string
    {
        $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        return $scheme . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost');
    }
}
