<?php
namespace App;

abstract class BaseJob
{
    public function __construct(int $priority)
    {
    }

    abstract public function exec(): void;

    protected function log(): void
    {
    }
}
