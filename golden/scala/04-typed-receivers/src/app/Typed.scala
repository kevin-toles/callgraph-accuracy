package app

trait Svc {
  def run(): Int
}

class FastSvc extends Svc {
  def run(): Int = 1
}

class Holder(private val svc: Svc) {
  def viaField(): Int = svc.run()

  def viaParam(s: FastSvc): Int = s.run()

  def viaLocal(): Int = {
    val s: Svc = new FastSvc()
    val f = new FastSvc()
    s.run()
    f.run()
  }

  def viaPattern(x: Any): Int = x match {
    case fs: FastSvc => fs.run()
    case _ => 0
  }

  def viaCatch(): String =
    try "ok"
    catch {
      case e: IllegalArgumentException => e.getMessage()
    }

  def viaBound[T <: Svc](t: T): Int = t.run()

  def viaFree[T](t: T): String = t.toString()
}
