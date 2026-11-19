let load path = String.trim path

let default_path = load " /etc/app "

let () = print_endline default_path
