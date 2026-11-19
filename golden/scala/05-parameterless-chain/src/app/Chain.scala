package app

class Node(val label: String) {
  def next(): Node = this
  def name(): String = label
}

class Walker(root: Node) {
  def walk(): String =
    root
      .next()
      .next()
      .name()
}
