package zio

trait ZIOBase {
  def map(f: Int => Int): ZIO = ???
}

sealed trait ZIO extends ZIOBase {
  def flatMap(f: Int => ZIO): ZIO = ???
}

object ZIO {
  def succeed(a: Int): ZIO = ???
}

object ZStream {
  def fromZIO(z: ZIO): ZIO = ???
}

abstract class Chunk extends scala.collection.immutable.Seq[Int]

object aliases {
  type Pipe[I, O] = I => O
}
