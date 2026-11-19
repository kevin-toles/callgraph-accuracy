<?php
namespace App;

class Dog extends Animal
{
    protected function sound(): string
    {
        return 'woof';
    }

    public function speak(): string
    {
        $this->describe();
        $this->sound();
        return parent::name();
    }
}
