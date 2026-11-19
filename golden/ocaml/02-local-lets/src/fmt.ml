let render items =
  let clean s = String.trim s in
  let joined = String.concat " " (List.map clean items) in
  let rec wrap n s =
    let pad t = String.concat "" ["["; t; "]"] in
    match n with
    | 0 -> s
    | _ -> wrap (pred n) (pad s)
  in
  wrap 2 joined

let () = print_endline (render ["a"; "b"])
