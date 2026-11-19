package app

import util.{Helper => H}
import model._
import other._

class Use {
  def go(): Int = {
    val h = new H()
    h.assist()
    val w: Widget = new Widget()
    w.draw()
  }
}
