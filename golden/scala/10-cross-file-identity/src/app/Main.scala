package app

import lib.Text
import lib.Sink

class Main(out: Sink) {
  def run(): Unit = {
    val t = Text.clean(" x ")
    out.emit(t)
  }
}
