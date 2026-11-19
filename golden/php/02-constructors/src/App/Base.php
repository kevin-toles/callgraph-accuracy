<?php
namespace App;

class Base
{
    public function __construct(string $name)
    {
        $this->setup();
    }

    protected function setup(): void
    {
    }
}
