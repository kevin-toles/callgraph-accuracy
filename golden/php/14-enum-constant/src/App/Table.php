<?php
namespace App;

class Table
{
    public function paint(): string
    {
        Suit::first();
        return Suit::Hearts->color();
    }
}
