def banner(text)
  text
end

class Installer
  def initialize(dir)
    @dir = dir
  end

  def install
    banner("go")
  end
end

banner("start")
Installer.new("/tmp").install
