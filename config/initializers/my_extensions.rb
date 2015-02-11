class Object
  def error?
    false
  end
  def error!
    self.define_singleton_method(:error?) { true }
    self
  end
end

class NilClass
  def clean
    nil
  end
  def error!
    raise 'Cannot make nil an error!'
  end
end

class String
  def clean
    s = self.strip
    return s.blank? ? nil : s.downcase
  end
  def ascii
    self.force_encoding('ascii-8bit')
  end
end
