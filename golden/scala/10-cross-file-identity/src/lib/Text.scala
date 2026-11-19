package lib

trait Sink {
  def emit(s: String): Unit
}

object Text {
  def clean(s: String): String = s.trim()

  def twice(s: String): String = clean(clean(s))
}
