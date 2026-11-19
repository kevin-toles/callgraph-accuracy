class Sync
  def initialize
  end

  def run(remote)
    data = JSON.generate(1)
    log = Logger.new(2)
    remote.push(data)
    finish(log)
  end

  def finish(data)
    data
  end
end
