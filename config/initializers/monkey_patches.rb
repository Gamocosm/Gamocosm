class Object
  def error?
    false
  end

  def silence(&block)
    begin
      block.call
    rescue => e
      msg = "Badness in #{self.class.name}: #{e}"
      Rails.logger.error msg
      Rails.logger.error e.backtrace.join("\n")
      ExceptionNotifier.notify_exception(e)
      msg.error! e
    end
  end
end

class NonblockIOTimeout < IOError
end

class IO
  def read_timeout(timeout, &block)
    begin
      return block.call
    rescue IO::WaitReadable
      ready = IO.select([self], nil, nil, timeout)
      if ready.nil?
        raise NonblockIOTimeout, 'Unable to read: timeout'
      end
      begin
        return block.call
      rescue IO::WaitReadable
        raise NonblockIOTimeout, 'Unable to read after IO#select ready'
      end
    end
    raise 'Should not reach here'
  end

  def write_timeout(timeout, &block)
    begin
      return block.call
    rescue IO::WaitWritable
      ready = IO.select(nil, [self], nil, timeout)
      if ready.nil?
        raise NonblockIOTimeout, 'Unable to write: timeout'
      end
      begin
        return block.call
      rescue IO::WaitWritable
        raise NonblockIOTimeout, 'Unable to write after IO#select ready'
      end
    end
    raise 'Should not reach here'
  end
end

class Error
  attr_reader :data
  attr_reader :msg

  def initialize(data, msg)
    @data = data
    @msg = msg
  end

  def error?
    true
  end

  def to_s
    msg
  end
end

class NilClass
  def clean
    nil
  end
end

class String
  def error!(data)
    Error.new(data, self)
  end

  def clean
    s = self.strip
    s.blank? ? nil : s.downcase
  end

  def ascii
    self.force_encoding('ascii-8bit')
  end
end

class ActiveSupport::EnvironmentInquirer
  def index
    if self.production?
      3
    elsif self.test?
      2
    else
      1
    end
  end
end
