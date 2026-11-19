class Shop
  def initialize(name)
    @name = name
    setup(name)
  end

  def setup(name)
    self.log(name)
  end

  def log(msg)
    msg
  end

  def name=(value)
    log(value)
  end

  def self.open(name)
    Shop.new(name)
  end
end
