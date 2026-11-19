module B = Base

let a () = Mid.greet "a"

let b () = Low.greet "b"

let c () = B.greet "c"

let d () =
  let module G = Low in
  G.wave ()
