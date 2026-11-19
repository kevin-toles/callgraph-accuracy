module Store
  class Item
    def initialize(id)
      @id = id
    end

    def self.create(id)
      new(id)
    end

    def self.load(id)
      item = new(id)
      item
    end
  end
end

Store::Item.create(1)
::Store::Item.load(2)
Store::Item.new(3)
