<?php
namespace App;

class Pipeline
{
    public function run(array $items): void
    {
        $double = function (int $x): int {
            return $this->scale($x);
        };
        $inc = fn (int $x): int => $this->shift($x);
        $double(1);
        $inc(2);
        $this->each($items, function ($item) {
            $this->scale($item);
        });
    }

    public function each(array $items, callable $f): void
    {
    }

    private function scale(int $x): int
    {
        return $x;
    }

    private function shift(int $x): int
    {
        return $x;
    }
}
