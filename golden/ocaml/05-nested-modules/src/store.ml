let log msg = print_endline msg

module Cache = struct
  let key k = String.lowercase_ascii k

  let get k = log (key k)

  module Stats = struct
    let hit k = get k
  end
end

let lookup k =
  Cache.get k;
  Cache.Stats.hit k

let () = lookup "A"
