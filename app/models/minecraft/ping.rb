class Minecraft::Ping
  VERSION = 0

  def initialize(ip_address, port = 25565)
    @ip_address = ip_address
    @port = port
    @rng = Random.new
    self.reset(nil)
  end

  def reset(con)
    @con = con
    @buf = ''.ascii
    @pos = 0
    @token = @rng.rand(256)
  end

  def create_varint(x)
    buf = []
    for _ in 0...5
      if x & ~0x7f == 0
        buf.push(x)
        return buf.pack('C*').ascii
      end
      buf.push((x & 0x7f) | 0x80)
      x >>= 7
    end
    raise "#{self.class.name} sending varint too big: #{x}"
  end

  def create_string(str)
    utf8 = str.encode('utf-8')
    return self.create_varint(utf8.bytesize) + utf8.ascii
  end

  def create_short(x)
    return [ x ].pack('S>').ascii
  end

  def create_long(x)
    return [ x ].pack('q>').ascii
  end

  def create_packet(id, buf)
    data = self.create_varint(id) + buf
    return self.create_varint(data.bytesize) + data
  end

  def handshake
    buf = self.create_varint(VERSION)
    buf += self.create_string(@ip_address)
    buf += self.create_short(@port)
    buf += self.create_varint(1)
    packet = self.create_packet(0, buf)
    @con.send(packet, 0)
  end

  def ping
    buf = self.create_long(@token)
    packet = self.create_packet(1, buf)
    @con.send(packet, 0)
  end

  def status
    buf = ''.ascii
    packet = self.create_packet(0, buf)
    @con.send(packet, 0)
  end

  def read
    data = @con.recv(1024)
    if data.encoding != @buf.encoding
      raise "Unexpected encoding from BasicSocket#recv: #{data.encoding}"
    end
    @buf += data
  end

  def read_n(n, advance)
    is_first = true
    while @pos + n > @buf.bytesize
      if !is_first
        sleep 2
      end
      self.read
      is_first = false
    end
    if advance
      ret = @buf.byteslice(@pos, n)
      @pos += n
      return ret
    end
    return nil
  end

  def read_varint
    x = 0
    for i in 0...5
      y = self.read_n(1, true).bytes.first
      x |= (y & 0x7f) << (7 * i)
      if y & 0x80 == 0
        return x
      end
    end
    raise 'Minecraft sent varint that was too big'
  end

  def read_utf8
    n = self.read_varint
    str = self.read_n(n, true)
    return str.force_encoding('utf-8')
  end

  def read_long
    bytes = self.read_n(8, true)
    return bytes.unpack('q>').first
  end

  def read_packet
    n = self.read_varint
    self.read_n(n, false)
    return self.read_varint
  end

  def read_ping
    id = self.read_packet
    if id != 1
      raise "Minecraft did not reply to ping with pong (got #{id})"
    end
    response = self.read_long
    if response != @token
      raise "Minecraft replied to ping #{@token} with pong #{response}"
    end
  end

  def read_status
    id = self.read_packet
    if id != 0
      raise "Unexpected reply from Minecraft for status (got #{id})"
    end
    status = self.read_utf8
    return JSON.parse(status)
  end

  # shoutout to radu
  def nike(t)
    begin
      Timeout::timeout(t) do
        Socket.tcp(@ip_address, @port) do |socket|
          self.reset(socket)
          self.handshake
          self.status
          ret = self.read_status
          self.ping
          self.read_ping
          return ret
        end
      end
    rescue => e
      msg = "Exception pinging Minecraft: #{e}"
      Rails.logger.error(msg)
      return msg.error!(e)
    end
    raise 'Should not reach here'
  end

  def players_online
    status = self.nike(2)
    if status.error?
      return status
    end
    online = status.try(:[], 'players').try(:[], 'online')
    if online.nil?
      return "Minecraft status unexpected format: #{status}".error!(status)
    end
    return online
  end

end
