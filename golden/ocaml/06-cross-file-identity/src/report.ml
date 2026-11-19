open Geom

let line r = Printf.sprintf "%f" (area r)

let both r =
  let open Geom in
  perimeter r

let paren r = Geom.(scaled r)
