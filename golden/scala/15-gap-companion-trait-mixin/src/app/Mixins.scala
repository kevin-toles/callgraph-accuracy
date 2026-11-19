package app

trait Logging {
  def log(msg: String): Unit = ()
}

trait Audit {
  def audit(): Unit
}

class Account

object Account extends Logging with Audit {
  def audit(): Unit = log("audit")
  def open(): Account = {
    log("open")
    new Account()
  }
}

class Bank {
  def run(): Unit = {
    Account.log("x")
    Account.open()
    Account.audit()
  }
}
