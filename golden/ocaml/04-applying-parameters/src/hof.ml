type handlers = { on_event : int -> unit }

let apply f x = f x

let twice g x = g (g x)

let with_logger ~log items =
  log "start";
  List.iter log items

let fire h = h.on_event 3

let run () =
  print_int (apply succ 1);
  print_int (twice pred 5);
  with_logger ~log:print_endline ["a"];
  fire { on_event = print_int }
