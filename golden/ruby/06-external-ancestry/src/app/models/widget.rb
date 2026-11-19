class Widget < ActiveRecord::Base
  def publish
    validate_all(1)
    self.save_now(2)
    format_name(3)
  end

  def format_name(x)
    x
  end
end
