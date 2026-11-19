<?php
namespace App;

class Form
{
    public const MAX = 3;
    private $data = [];

    public function check($input): bool
    {
        if (isset($input['a']) || empty($input['b'])) {
            unset($input['c']);
        }
        list($x, $y) = array(1, 2);
        echo $this->data;
        $n = (int) $input;
        $cls = Form::class;
        $max = self::MAX;
        $ref = [$this, 'valid'];
        $closure = $this->valid(...);
        return $this->valid($input instanceof Form);
    }

    private function valid(bool $ok): bool
    {
        return $ok;
    }
}
