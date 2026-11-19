<?php
namespace App;

trait Greets
{
    public function hello(): string
    {
        return 'hi ' . $this->name();
    }

    abstract public function name(): string;
}
