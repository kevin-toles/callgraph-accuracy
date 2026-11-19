class ActiveSupport::Notifier
  def ping
    instrument(2)
  end
end
