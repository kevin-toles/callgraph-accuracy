package app

import java.util.ArrayList

class Guess {
  def go(xs: ArrayList[String]): Int = {
    val it = xs.iterator()
    it.next()
    xs.get(0).length()
  }
}
