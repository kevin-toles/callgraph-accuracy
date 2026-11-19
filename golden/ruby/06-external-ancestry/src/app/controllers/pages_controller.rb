module Config
  def self.parent_class
    Object
  end
end

class PagesController < Config.parent_class
  def show
    render_page(1)
  end
end
