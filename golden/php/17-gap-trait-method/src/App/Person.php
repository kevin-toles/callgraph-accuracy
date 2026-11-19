<?php
namespace App;

class Person
{
    use Greets;

    public function name(): string
    {
        return 'p';
    }

    public function intro(): string
    {
        return $this->hello();
    }
}
