class Minecraft::Querier
  MAGIC = "\xfe\xfd"
  PACKET_TYPE_CHALLENGE = 9
  PACKET_TYPE_QUERY = 0
  TIMEOUT = 1

  def initialize(ip_address, port = 25565)
    @ip_address = ip_address
    @port = port
  end

  def handshake(socket)
    data = self.class.create_packet(PACKET_TYPE_CHALLENGE, 0, '')
    socket.write_timeout(TIMEOUT) do
      socket.write_nonblock(data)
    end
    data = socket.read_timeout(TIMEOUT) do
      socket.read_nonblock(256)
    end
    challenge = data.ascii[5...-1].to_i
    return challenge
  end

  def read_all(tries = 4)
    socket = Socket.new(:INET, :DGRAM)
    begin
      address = Socket.pack_sockaddr_in(@port, @ip_address)
      socket.write_timeout(TIMEOUT) do
        socket.connect_nonblock(address)
      end
      challenge = self.handshake(socket)
      # 32 bit unsigned network order (big endian)
      data = self.class.create_packet(PACKET_TYPE_QUERY, 0, [challenge].pack('N'))
      socket.write_timeout(TIMEOUT) do
        socket.write_nonblock(data)
      end
      data = socket.read_timeout(TIMEOUT) do
        socket.read_nonblock(4096)
      end
      return data.ascii[5..-1].split("\0")
    rescue => e
      msg = "Exception querying Minecraft: #{e}"
      Rails.logger.error(msg)
      return msg.error!(e)
    ensure
      socket.close
    end
    raise 'Should not reach here'
  end

  def self.create_packet(id, session, data)
    # 8 bit signed, 32 bit unsigned big endian
    return MAGIC.ascii + [id].pack('c').ascii + [session].pack('N').ascii + data.ascii
  end

  def read_num_players
    data = self.read_all
    if data.error?
      return data
    end
    return data[3].to_i
  end

end
