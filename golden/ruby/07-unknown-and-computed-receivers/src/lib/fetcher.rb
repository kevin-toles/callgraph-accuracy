class Fetcher
  def initialize
  end

  def run
    1
  end

  def fetch(conn, opts)
    conn.get(1)
    opts.fetch(:a).strip()
    "abc".upcase()
    [1, 2].first()
    conn.pool().checkout()
    f = Fetcher.new
    f.run()
  end
end
