<?php
declare(strict_types=1);

namespace Core;

class Router
{
    private array $routes = [];

    /** Daftarkan route. $handler = [Kelas::class, 'metode']. */
    public function add(string $method, string $pattern, array $handler, bool $auth = true): void
    {
        $regex = '#^' . preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $pattern) . '$#';
        $this->routes[] = compact('method', 'regex', 'handler', 'auth');
    }

    public function dispatch(Request $req): void
    {
        $pathMatched = false;
        foreach ($this->routes as $r) {
            if (!preg_match($r['regex'], $req->path(), $m)) {
                continue;
            }
            $pathMatched = true;
            if ($r['method'] !== $req->method()) {
                continue;
            }
            $req->params = array_filter($m, 'is_string', ARRAY_FILTER_USE_KEY);
            $user = $r['auth'] ? Auth::user($req) : null;
            [$class, $method] = $r['handler'];
            $result = (new $class())->$method($req, $user);
            Response::json($result['kode'] ?? 200, $result['pesan'] ?? 'Berhasil', $result['data'] ?? null);
        }
        if ($pathMatched) {
            throw new HttpException('Method tidak diizinkan', 405);
        }
        throw new HttpException('Endpoint tidak ditemukan', 404);
    }
}
