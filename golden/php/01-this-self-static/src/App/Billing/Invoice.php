<?php
namespace App\Billing;

use App\Svc;

class Invoice
{
    public function total(): int
    {
        Svc::log();
        \App\Svc::log();
        return $this->sum();
    }

    private function sum(): int
    {
        return 0;
    }
}
