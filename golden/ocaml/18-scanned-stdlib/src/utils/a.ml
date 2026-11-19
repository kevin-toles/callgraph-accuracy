let run f l =
  print_string "x";
  Stdlib.failwith "y";
  List.map f l
