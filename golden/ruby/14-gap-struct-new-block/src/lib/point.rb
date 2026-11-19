module Calc
  def self.square(n)
    n
  end
end

Point = Struct.new(:x, :y) do
  def norm
    Calc.square(2)
  end

  def describe
    norm()
  end
end
