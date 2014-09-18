class Object
  def error?
    return false
  end

  def error!
    if self.nil?
      raise 'Cannot make nil an error!'
    end
    self.define_singleton_method(:error?) { true }
    self
  end
end
