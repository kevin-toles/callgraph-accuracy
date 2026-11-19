module Geo
  ORIGIN = Struct.new(:x, :y).new(0, 0)

  class Shape
    attr_accessor :name
    include Comparable
  end
end
