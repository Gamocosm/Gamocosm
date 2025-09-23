#!/usr/bin/env -S rails runner

ENDPOINT = Async::DNS::Endpoint.for('0.0.0.0', port: 5300)

IN = Resolv::DNS::Resource::IN

begin
  RubyDNS.run(ENDPOINT) do
    match(/^([a-z]+)\.#{Gamocosm::USER_SERVERS_DOMAIN}$/, IN::A) do |transaction, match_data|
      domain = match_data[1]
      server = Server.find_by(domain:)
      if !server.nil?
        ip_address = server.remote.ip_address
        if !ip_address.nil? && !ip_address.error?
          transaction.respond!(ip_address)
        else
          transaction.respond!('127.0.0.1')
        end
      else
        transaction.respond!('127.0.0.1')
      end
    end

    otherwise do |transaction|
      transaction.fail!(:NXDomain)
    end
  end
rescue Interrupt
  puts 'Caught SIGINT; exiting.'
rescue SignalException => e
  if e.signo == Signal.list['TERM']
    puts 'Caught SIGTERM; exiting.'
  else
    raise
  end
end
