package app

import java.util.ArrayList
import java.util.concurrent._

class Item(val name: String)

class Factory {
  def build(): ArrayList[Item] = {
    val list = new ArrayList[Item]()
    list.add(new Item("a"))
    val cache = new ConcurrentHashMap[String, Item]()
    cache.clear()
    list
  }

  def fail(): Nothing = throw new IllegalStateException("bad")
}
