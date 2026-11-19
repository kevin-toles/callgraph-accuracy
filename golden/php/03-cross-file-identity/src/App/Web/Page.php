<?php
namespace App\Web;

use App\Lib\Util;
use App\Lib\Util as U;
use function App\Lib\slug;

class Page
{
    public function render(string $t): string
    {
        $a = Util::fmt($t);
        $b = U::trim($t);
        $c = slug($t);
        return \App\Lib\slug($a . $b . $c);
    }
}
