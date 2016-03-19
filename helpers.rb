class Object
  def exists?
    true
  end
end

class NilClass
  def exists?
    false
  end
end

class Tempfile
  def persist(path)
    FileUtils.cp(self.path, path)
  end
end
