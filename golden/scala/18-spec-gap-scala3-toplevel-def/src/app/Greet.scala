package app

def greet(n: String): String = n.trim()

class Caller {
  def go(): String = greet("a")
}
