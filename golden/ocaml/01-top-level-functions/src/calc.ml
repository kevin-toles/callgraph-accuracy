let double n = abs n

let describe n =
  String.concat " " ["value"; string_of_int (double n)]

let report xs =
  String.concat
    ","
    (List.map
       describe
       (List.rev xs))

let () =
  print_endline (describe 4);
  print_int (String.length (report [1; 2]))
