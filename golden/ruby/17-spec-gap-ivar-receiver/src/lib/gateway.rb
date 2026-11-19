class Gateway
  def initialize(client, hook)
    @client = client
    @hook = hook
  end

  def send_it
    @client.post(1)
    @hook.call(2)
  end
end
