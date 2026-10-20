<?php
declare(strict_types=1);

namespace Core;

/** Error yang sengaja dilempar controller dan diubah jadi respons JSON. */
class HttpException extends \RuntimeException
{
    public function __construct(string $message, public int $status = 400, public array $errors = [])
    {
        parent::__construct($message, $status);
    }
}
