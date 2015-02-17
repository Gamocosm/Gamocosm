class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    user = server.user
    begin
      if !server.remote.exists?
        server.log('Error starting server; remote_id is nil. Aborting')
        server.reset_state
        return
      end
      if server.remote.error?
        server.log("Error communicating with Digital Ocean while starting server: #{server.remote.error}. Aborting")
        server.reset_state
        return
      end
      event = user.digital_ocean.droplet_action_show(server.remote_id, digital_ocean_action_id)
      if event.error?
        server.log("Error with Digital Ocean start server action #{digital_ocean_action_id}; #{event}. Aborting")
        server.reset_state
        return
      elsif event.failed?
        server.log("Starting server on Digital Ocean failed: #{event}. Aborting")
        server.reset_state
        return
      end
      server.refresh_domain
      if !event.done?
        times += 1
        if times >= 64
          server.log('Digital Ocean took too long to start server. Aborting')
          server.reset_state
          return
        elsif times >= 32
          server.log("Still waiting for Digital Ocean server to start, tried #{times} times")
        end
        WaitForStartingServerWorker.perform_in(4.seconds, server_id, digital_ocean_action_id, times)
        return
      end
      if server.remote.status != 'active'
        server.log("Finished starting server on Digital Ocean, but remote status was #{server.remote.status} (not 'active'). Aborting")
        server.reset_state
        return
      end
      server.update_columns(pending_operation: 'preparing')
      SetupServerWorker.perform_in(4.seconds, server_id)
    rescue => e
      server.log("Background job waiting for starting server failed: #{e}")
      server.reset_state
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
