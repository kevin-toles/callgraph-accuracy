<?php

use App\Kernel;

$env = getenv('APP_ENV');
$kernel = new Kernel($env);
$kernel->boot();
boot_env();

function boot_env(): void
{
    $kernel = new App\Kernel('cli');
}
