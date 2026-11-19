class Report
  def render(row)
    Util.fmt(row)
    Util.wrap(row)
  end
end

Util.fmt(0)
