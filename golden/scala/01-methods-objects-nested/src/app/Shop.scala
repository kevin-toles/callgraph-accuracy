package app

class Shop {
  def total(): Int = {
    val a = this.price()
    val b = price()
    a
  }

  def price(): Int = Shop.base()

  def open(): Int = {
    val inner = new Shop.Clerk()
    inner.serve()
  }
}

object Shop {
  def base(): Int = Pricing.round(5)

  class Clerk {
    def serve(): Int = greet()
    def greet(): Int = 1
  }
}

object Pricing {
  def round(x: Int): Int = x
}
