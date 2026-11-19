<?php
namespace App;

class Events
{
    private $handler;
    private $onDone;

    public function fire(callable $cb, $value): void
    {
        $cb($value);
        ($this->handler)($value);
        ($this->onDone)();
        $fn = $this->factory();
        $fn($value);
    }

    public function factory(): callable
    {
        return $this->handler;
    }
}
