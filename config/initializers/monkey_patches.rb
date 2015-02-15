class Object
  def error?
    false
  end
  def error!
    self.define_singleton_method(:error?) { true }
    self
  end
  def silence(&block)
    begin
      return block.call
    rescue => e
      msg = "Badness in #{self.class.name}: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      ExceptionNotifier.notify_exception(e)
      return msg.error!
    end
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
