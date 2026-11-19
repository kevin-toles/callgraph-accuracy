<?php

class Legacy
{
    private $client;

    public function sync($payload)
    {
        $this->client->send($payload);
        $payload->validate();
        $this->build()->commit();
        $this->client->items[0]->flush();
        undefined_helper($payload);
    }

    public function build()
    {
        return $this->client;
    }
}
