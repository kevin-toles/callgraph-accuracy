<?php
namespace App;

abstract class Animal
{
    public function describe(): string
    {
        return $this->name() . $this->sound();
    }

    abstract protected function sound(): string;

    protected function name(): string
    {
        return 'animal';
    }
}
