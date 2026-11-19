module Outer
  module Codec
    class Json
      def self.go(x)
        x
      end
    end
  end

  class Inner
    def initialize
    end

    def run
      Codec::Json.go(1)
      Inner.new
    end
  end
end

Outer::Inner.new.run
