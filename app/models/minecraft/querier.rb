require 'socket'

class Minecraft::Querier
  MAGIC = "\xfe\xfd"
  PACKET_TYPE_CHALLENGE = 9
  PACKET_TYPE_QUERY = 0

  def initialize(ip_address, port = 25565)
    @ip_address = ip_address
    @port = port
  end

  def handshake
    @connection.send(self.create_packet(PACKET_TYPE_CHALLENGE), 0)
    data = @connection.recvfrom(256)[0]
    @challenge = data[5...-1].to_i
  end

  def read_all(tries = 4)
    @connection = UDPSocket.new
    @connection.connect(@ip_address, @port)
    begin
      for i in 0...tries do
        begin
          @challenge = 0
          self.handshake
          @connection.send(self.create_packet(PACKET_TYPE_QUERY) + [@challenge].pack('N'), 0) # 32 bit unsigned big endian
          data = @connection.recvfrom(4096)[0][5...-1].split("\x00")
          return data
        rescue
        end
      end
    ensure
      @connection.close()
    end
    return nil
  end

  def create_packet(id)
    return (MAGIC + [id].pack('C') + [0].pack('L')).force_encoding('ascii-8bit') # 8 bit unsigned, 32 bit unsigned native endian
  end

  def read_num_players
    data = self.read_all
    return data.nil? ? nil : data[3].to_i
  end

end
