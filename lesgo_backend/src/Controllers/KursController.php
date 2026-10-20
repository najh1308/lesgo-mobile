<?php
declare(strict_types=1);

namespace Controllers;

use Core\Request;

/** Kurs IDR -> USD/EUR/JPY dari Frankfurter (data ECB). Dicache 6 jam; ada kurs cadangan jika offline. */
class KursController
{
    private const CACHE_TTL = 6 * 3600;

    // Kurs cadangan (perkiraan kasar) hanya dipakai jika API tidak bisa dihubungi dan belum ada cache.
    private const CADANGAN = ['USD' => 0.000060, 'EUR' => 0.000052, 'JPY' => 0.0090];

    public function index(Request $req): array
    {
        $file = dirname(__DIR__, 2) . '/storage/kurs.json';
        if (is_file($file) && time() - filemtime($file) < self::CACHE_TTL) {
            return ['data' => json_decode(file_get_contents($file), true)];
        }

        $ctx = stream_context_create(['http' => ['timeout' => 4, 'ignore_errors' => true]]);
        $res = @file_get_contents('https://api.frankfurter.dev/v1/latest?base=IDR&symbols=USD,EUR,JPY', false, $ctx);
        $json = $res ? json_decode($res, true) : null;

        if (is_array($json) && isset($json['rates']['USD'], $json['rates']['EUR'], $json['rates']['JPY'])) {
            $data = [
                'base' => 'IDR', 'tanggal' => $json['date'] ?? null, 'sumber' => 'frankfurter',
                'rates' => ['IDR' => 1.0, 'USD' => (float) $json['rates']['USD'], 'EUR' => (float) $json['rates']['EUR'], 'JPY' => (float) $json['rates']['JPY']],
            ];
            file_put_contents($file, json_encode($data));
            return ['data' => $data];
        }

        // Gagal ambil dari API: pakai cache lama jika ada, kalau tidak pakai kurs cadangan.
        if (is_file($file)) {
            $data = json_decode(file_get_contents($file), true);
            $data['sumber'] = 'cache';
            return ['data' => $data];
        }
        return ['data' => [
            'base' => 'IDR', 'tanggal' => null, 'sumber' => 'cadangan',
            'rates' => ['IDR' => 1.0] + self::CADANGAN,
        ]];
    }
}
