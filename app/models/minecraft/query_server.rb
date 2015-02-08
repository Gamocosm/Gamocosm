require 'socket'

class Minecraft::QueryServer
  attr_accessor :so_it_goes
  attr_accessor :drop_packets
  attr_accessor :num_players

  def initialize(port = 25565)
    @port = port
    @challenge_token_time = 0
    @challenge_token = 0
    @so_it_goes = false
    @drop_packets = false
    @num_players = 0
  end

  def log(msg)
    Rails.logger.info "#{self.class.name}: #{msg}"
  end

  def regenerate_challenge_token
    if (Time.new - @challenge_token_time).to_i > 30
      @challenge_token_time = Time.new
      @challenge_token = rand(2 ** 32 - 1)
    end
    @challenge_token
  end

  def run
    socket = UDPSocket.new
    begin
      log 'Starting.'
      socket.bind('localhost', @port)
      while !@so_it_goes
        begin
          Timeout::timeout(2) do
            listen_loop(socket)
          end
        rescue Timeout::Error
          # ignore
        end
      end
      log 'Ended.'
    ensure
      socket.close
    end
  end

  def listen_loop(socket)
    (data, (_, port, _, ip)) = socket.recvfrom(512)
    data = data.ascii
    log "Received #{data.bytes}."
    if data[0...2] == Minecraft::Querier::MAGIC.ascii
      res = handle_packet(data[2..-1])
      if !res.nil? && !@drop_packets
        log "Sending #{res.bytes}."
        socket.send(res, 0, ip, port)
      end
    else
      log 'Bad magic.'
    end
  end

  def handle_packet(data)
    # 'c' is 8 bit signed
    packet_type = data[0].try(:unpack, 'c').try(:first)
    if packet_type.nil?
      log 'Bad packet type.'
      return nil
    end
    # 'N' is 32 bit unsigned, big endian
    session_id = data[1...5].try(:unpack, 'N').try(:first)
    if session_id.nil?
      log 'Bad session id.'
      return nil
    end
    rest = data[5..-1]
    if packet_type == Minecraft::Querier::PACKET_TYPE_CHALLENGE
      return handle_packet_challenge(session_id, rest)
    elsif packet_type == Minecraft::Querier::PACKET_TYPE_QUERY
      return handle_packet_query(session_id, rest)
    else
      log "Unknown packet type #{packet_type}."
    end
    nil
  end

  def handle_packet_challenge(session_id, data)
    return Minecraft::Querier.create_packet(Minecraft::Querier::PACKET_TYPE_CHALLENGE, session_id, "#{regenerate_challenge_token}\0")[2..-1]
  end

  def handle_packet_query(session_id, data)
    # 'N' is 32 bit unsigned, big endian
    supplied_challenge = data[0...4].try(:unpack, 'N').try(:first)
    if supplied_challenge != regenerate_challenge_token
      log "Bad challenge #{supplied_challenge}."
      return nil
    end
    return Minecraft::Querier.create_packet(Minecraft::Querier::PACKET_TYPE_QUERY, session_id, [
      'motd',
      'gametype',
      'map',
      @num_players.to_s,
    ].join("\0"))[2..-1]
  end
end
