<?php
namespace App\Lib;

function slug(string $s): string
{
    return Util::trim($s);
}

class Util
{
    public static function trim(string $s): string
    {
        return $s;
    }

    public static function fmt(string $s): string
    {
        return slug(self::trim($s));
    }
}
