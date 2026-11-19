<?php
namespace App;

class Factory
{
    public function make(): Handler
    {
        $job = new class (5) extends BaseJob {
            public function exec(): void
            {
                $this->log();
            }
        };
        return new class implements Handler {
            public function handle(): void
            {
                Factory::audit();
            }
        };
    }

    public static function audit(): void
    {
    }
}
