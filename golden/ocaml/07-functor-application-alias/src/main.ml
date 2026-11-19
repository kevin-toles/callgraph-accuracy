module P = struct
  let name = "x"
end

module F = Filegen.Make (P)

let start () = F.connect ()

let () = start ()
