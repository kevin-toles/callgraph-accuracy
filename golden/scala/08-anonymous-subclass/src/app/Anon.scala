package app

trait Greeter {
  def greet(): String
}

abstract class Task(val id: Int) {
  def exec(): Unit
}

class Spawner {
  def helper(): String = "h"

  def make(): Unit = {
    val r = new Runnable {
      def run(): Unit = helper()
    }
    val g = new Greeter {
      def greet(): String = helper()
    }
    val t = new Task(7) {
      def exec(): Unit = helper()
    }
  }
}
