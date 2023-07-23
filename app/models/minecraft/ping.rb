class Minecraft::Ping
  VERSION = 0
  TIMEOUT = 1

  def initialize(ip_address, port = 25565)
    @ip_address = ip_address
    @port = port
    self.reset(nil)
  end

  def reset(con)
    @con = con
    @buf = ''.ascii
    @pos = 0
    @token = Random.rand(256)
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
    self.create_varint(utf8.bytesize) + utf8.ascii
  end

  def create_short(x)
    [x].pack('S>').ascii
  end

  def create_long(x)
    [x].pack('q>').ascii
  end

  def create_packet(id, buf)
    data = self.create_varint(id) + buf
    self.create_varint(data.bytesize) + data
  end

  def handshake
    buf = self.create_varint(VERSION)
    buf += self.create_string(@ip_address)
    buf += self.create_short(@port)
    buf += self.create_varint(1)
    packet = self.create_packet(0, buf)
    self.send(packet)
  end

  def ping
    buf = self.create_long(@token)
    packet = self.create_packet(1, buf)
    self.send(packet)
  end

  def status
    buf = ''.ascii
    packet = self.create_packet(0, buf)
    self.send(packet)
  end

  def read
    data = self.recv(1024)
    if data.encoding != @buf.encoding
      raise "Unexpected encoding from read: #{data.encoding}"
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
    nil
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
    str.force_encoding('utf-8')
  end

  def read_long
    bytes = self.read_n(8, true)
    bytes.unpack('q>').first
  end

  def read_packet
    n = self.read_varint
    self.read_n(n, false)
    self.read_varint
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
    JSON.parse(status)
  end

  def connect
    address = Socket.pack_sockaddr_in(@port, @ip_address)
    @con.write_timeout(TIMEOUT) do
      @con.connect_nonblock(address)
    end
  end

  def send(data)
    @con.write_timeout(TIMEOUT) do
      @con.write_nonblock(data)
    end
  end

  def recv(n)
    @con.read_timeout(TIMEOUT) do
      @con.read_nonblock(n)
    end
  end

  # shoutout to radu
  def nike
    socket = Socket.new(:INET, :STREAM)
    begin
      self.reset(socket)
      self.connect
      self.handshake
      self.status
      ret = self.read_status
      self.ping
      self.read_ping
      return ret
    rescue => e
      msg = "Exception pinging Minecraft: #{e}"
      Rails.logger.error(msg)
      return msg.error!(e)
    ensure
      socket.close
    end
    raise 'Should not reach here'
  end

  def players_online
    status = self.nike
    if status.error?
      return status
    end
    online = status.try(:[], 'players').try(:[], 'online')
    if online.nil?
      return "Minecraft status unexpected format: #{status}".error!(status)
    end
    online
  end

end
