<?php
namespace App;

class UserCtl extends BaseCtl
{
    public function show(): void
    {
        $this->logger->info('show');
    }
}
