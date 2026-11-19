class counter =
  object
    val mutable n = 0
    method incr = n <- succ n
  end

class loud =
  object (self)
    inherit counter
    method shout = self#incr; print_endline "up"
  end
