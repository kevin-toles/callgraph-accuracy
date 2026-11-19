package app

class Config {
  val size: Int = Config.compute()
  lazy val label: String = describe()

  def describe(): String = "cfg"
}

object Config {
  val defaults: Int = compute()

  def compute(): Int = 4
}
