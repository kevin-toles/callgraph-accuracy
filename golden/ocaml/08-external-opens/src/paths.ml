open Printf

let show_dir d = printf "%s\n" d

let join d f =
  let open Filename in
  concat d (basename f)

let quoted s = Filename.quote s
