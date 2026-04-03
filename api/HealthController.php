<?php
require_once __DIR__.'/config.php';
require_once __DIR__.'/Response.php';

class HealthController {
    public static function status(): void {
        try {
            $pdo = db();
            $ok = (int)$pdo->query('SELECT 1')->fetchColumn() === 1;
            Response::json(['ok'=>$ok, 'time'=>gmdate('c')]);
        } catch (Throwable $e) {
            Response::json(['ok'=>false, 'error'=>$e->getMessage()], 500);
        }
    }
}
