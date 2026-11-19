let direct r = Geomlib.Shapes.area r

open Geomlib

let opened r = Shapes.perimeter r

let () = print_float (direct 1.0)
