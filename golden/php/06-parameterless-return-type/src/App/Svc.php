<?php
namespace App;

class Svc
{
    public function store(): Store
    {
        return new Store();
    }

    public function storeFor(int $shard): Store
    {
        return new Store();
    }

    public function run(): void
    {
        $this->store()->find(1);
        $this->storeFor(2)->find(3);
    }
}
