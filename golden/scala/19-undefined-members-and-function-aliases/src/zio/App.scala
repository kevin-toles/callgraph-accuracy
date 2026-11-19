package zio

import zio.aliases._

object App {
  def run(z: ZIO, c: Chunk, pipe: Pipe[Int, Int]): Unit = {
    ZStream.fromEffect(z)
    ZIO(1)
    ZIO.succeed(1)
    ZStream.fromZIO(z)
    z.map(x => x)
    z.bracket(1)
    c.take(1)
    z.toString()
    pipe(1)
  }
}
