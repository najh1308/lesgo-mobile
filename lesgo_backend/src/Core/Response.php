<?php
declare(strict_types=1);

namespace Core;

class Response
{
    /** Format seragam: status, pesan, data. */
    public static function json(int $code, string $pesan, mixed $data = null, array $errors = []): never
    {
        http_response_code($code);
        header('Content-Type: application/json; charset=utf-8');
        $out = [
            'status' => $code < 400 ? 'sukses' : 'gagal',
            'pesan'  => $pesan,
            'data'   => $data,
        ];
        if ($errors) {
            $out['errors'] = $errors;
        }
        echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);
        exit;
    }
}
