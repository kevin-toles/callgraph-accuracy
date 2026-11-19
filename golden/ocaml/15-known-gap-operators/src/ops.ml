let ( +++ ) a b = List.append a b

let total xs = List.length xs + 1

let piped xs = xs |> List.rev |> List.length

let applied xs = print_int @@ total xs

let combined a b = a +++ b
