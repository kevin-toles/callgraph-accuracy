class Hooks
  def fire(cb, &block)
    cb.call(1)
    block.call(2)
    cb.(3)
    fmt = ->(x) { notify(x) }
    fmt.call(4)
  end

  def notify(x)
    x
  end
end
