<?php
namespace App;

class Report
{
    private $db;

    public function rows(): array
    {
        return $this->db
            ->table('orders')
            ->where('paid', true)
            ->get();
    }
}
