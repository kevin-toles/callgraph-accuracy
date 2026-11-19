package app

class Animal(val legs: Int) {
  def speak(): String = sound()
  def sound(): String = "..."
  def describe(): String = "animal"
}

class Dog(n: Int) extends Animal(n) {
  override def describe(): String = {
    val s = super.describe()
    this.speak()
  }
}

class Keeper {
  def visit(d: Dog): String = d.speak()
}

class Worker extends Thread() {
  def go(): Unit = start()
  override def run(): Unit = super.run()
}
