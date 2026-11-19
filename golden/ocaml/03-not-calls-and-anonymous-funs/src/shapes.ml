type shape = Circle of float | Square of float

type point = { x : float; y : float }

module type SHAPE = sig
  val area : shape -> float
end

external raw_sqrt : float -> float = "caml_sqrt_float"

let area s =
  match s with
  | Circle _ -> Float.pi
  | Square side -> Float.abs side

let origin () = { x = 0.0; y = 0.0 }

let first_x p = Float.abs p.x

let check s =
  match s with
  | Circle _ -> raise (Failure "circle")
  | Square _ -> invalid_arg "square"

let all xs = List.iter print_endline xs

let labels xs = List.map (fun x -> string_of_float (area x)) xs

let build () = Some (Circle 1.0)
