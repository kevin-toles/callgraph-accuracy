<?php
namespace App;

class Svc
{
    public function run(): void
    {
        $this->prepare();
        self::log();
        Svc::log();
    }

    private function prepare(): void
    {
        $this->finish();
    }

    public static function log(): void
    {
    }

    private function finish(): void
    {
    }
}
