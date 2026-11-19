module Make = functor (X : sig val start : int end) -> struct
  let first () = succ X.start

  let show () = print_int (first ())
end

module Fresh = functor () -> struct
  let bump r = incr r
end

module M = Make (struct let start = 1 end)

module F = Fresh ()

let run r =
  M.show ();
  F.bump r
