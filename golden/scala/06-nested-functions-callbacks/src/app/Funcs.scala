package app

class Runner(onDone: () => Unit) {
  def each(f: Int => Unit): Unit = f(1)

  def log(x: Int): Unit = ()

  def finish(): Unit = onDone()

  def compute(): Int = {
    def twice(x: Int): Int = x
    val ident = (y: Int) => twice(y)
    each(v => log(v))
    ident(twice(3))
  }

  def apply2(g: Int => Int): Int = g(2)
}
