<?php
namespace App;

enum Suit: string
{
    case Hearts = 'h';
    case Spades = 's';

    public function color(): string
    {
        return $this->isRed() ? 'red' : 'black';
    }

    public function isRed(): bool
    {
        return $this === Suit::Hearts;
    }

    public static function first(): self
    {
        return self::Hearts;
    }
}
