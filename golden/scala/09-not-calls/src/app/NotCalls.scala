package app

class Rec(val total: Int)

class Ops {
  def handle(x: Int): Unit = ()

  def visit(f: Int => Unit): Unit = ()

  def go(o: Any, r: Rec): Int = {
    visit(handle)
    visit(handle _)
    val rr = o.asInstanceOf[Rec]
    r.total
  }
}
