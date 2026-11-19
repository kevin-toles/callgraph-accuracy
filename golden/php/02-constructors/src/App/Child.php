<?php
namespace App;

use Vendor\Mailer;

class Child extends Base
{
    private $mailer;
    private $when;

    public function __construct()
    {
        parent::__construct('child');
        $this->mailer = new Mailer();
        $this->when = new \DateTimeImmutable();
    }

    public static function make(): Child
    {
        return new Child();
    }

    public function copy(): self
    {
        return new self();
    }
}
