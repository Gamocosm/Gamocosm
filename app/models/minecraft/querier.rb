require 'socket'

class Minecraft::Querier
  MAGIC = "\xfe\xfd"
  PACKET_TYPE_CHALLENGE = 9
  PACKET_TYPE_QUERY = 0

  def initialize(ip_address, port = 25565)
    @ip_address = ip_address
    @port = port
  end

  def handshake(connection)
    connection.send(self.class.create_packet(PACKET_TYPE_CHALLENGE, 0, ''), 0)
    data = connection.recvfrom(256).first.ascii
    challenge = data[5...-1].to_i
    return challenge
  end

  def read_all(tries = 4)
    connection = UDPSocket.new
    begin
      Timeout::timeout(2) do
        connection.connect(@ip_address, @port)
        challenge = self.handshake(connection)
        # 32 bit unsigned big endian
        connection.send(self.class.create_packet(PACKET_TYPE_QUERY, 0, [challenge].pack('N')), 0)
        return connection.recvfrom(4096).first.ascii[5..-1].split("\0")
      end
    rescue => e
      msg = "Exception querying Minecraft: #{e}"
      Rails.logger.error(msg)
      return msg.error!(e)
    ensure
      connection.close
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
