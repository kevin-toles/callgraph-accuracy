<?php
namespace App;

use Vendor\Clock;

class Svc
{
    private Repo $repo;
    private ?Repo $backup = null;

    public function __construct(private Greeter $greeter)
    {
        $this->repo = new Repo();
    }

    public function handle(Repo $r, Greeter $g, Clock $clock): void
    {
        $r->find(1);
        $g->greet();
        $this->repo->save();
        $this->backup->save();
        $this->greeter->greet();
        $clock->tick();
        $local = new Repo();
        $local->find(2);
        try {
            $r->save();
        } catch (\RuntimeException $e) {
            $e->getMessage();
        }
    }
}
