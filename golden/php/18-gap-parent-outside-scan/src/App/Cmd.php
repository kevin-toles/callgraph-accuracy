<?php
namespace App;

use Symfony\Component\Console\Command\Command;

class Cmd extends Command
{
    public function __construct()
    {
        parent::__construct('cmd');
    }

    protected function configure(): void
    {
        parent::configure();
        $this->setName('x');
    }
}
