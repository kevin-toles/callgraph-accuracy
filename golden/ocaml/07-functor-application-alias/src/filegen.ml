module type NAMED = sig
  val name : string
end

module Make (P : NAMED) = struct
  let path () = Filename.concat "/tmp" P.name

  let connect () = print_endline (path ())
end
