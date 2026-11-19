class counter =
  object (self)
    val mutable n = 0

    method incr = n <- succ n

    method incr_twice =
      self#incr;
      self#incr

    method get = n
  end

let run () =
  let c = new counter in
  c#incr_twice;
  print_int c#get
