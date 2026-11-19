class Batch
  def process(items)
    items.each do |item|
      handle(item)
    end
    items.map { |i| handle(i) }
    register(->(x) { handle(x) })
  end

  def handle(x)
    x
  end

  def register(fn)
    fn
  end
end
