class Legacy
  def run(job)
    prepare_env(job)
    job.execute()
  end
end

puts("loaded")
bootstrap(1)
