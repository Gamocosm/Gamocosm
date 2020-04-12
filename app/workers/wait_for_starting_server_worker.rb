class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  CHECK_INTERVAL = Rails.env.test? ? 2.seconds : 4.seconds

  def perform(server_id, digital_ocean_action_id, times = 0, log_success = false)
    logger.info "Running #{self.class.name} with server_id #{server_id}, times #{times}"
    server = Server.find(server_id)
    user = server.user
    times += 1
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
        if times >= 64
          server.log('Digital Ocean took too long to start server. Aborting')
          server.reset_state
          return
        elsif times >= 32
          server.log("Still waiting for Digital Ocean server to start, tried #{times} times")
          log_success = true
        end
        WaitForStartingServerWorker.perform_in(CHECK_INTERVAL, server_id, digital_ocean_action_id, times, log_success)
        return
      end
      if server.remote.status != 'active'
        if times >= 64
          server.log("Finished starting server on Digital Ocean, but remote status was #{server.remote.status} (not 'active'). Aborting")
          server.reset_state
        else
          server.log("Finished starting server on Digital Ocean, but remote status was #{server.remote.status} (not 'active'). Trying again (tried #{times} times)")
          WaitForStartingServerWorker.perform_in(CHECK_INTERVAL, server_id, digital_ocean_action_id, times, true)
        end
        return
      end
      if log_success
        server.log('Server started successfully')
      end
      server.update_columns(pending_operation: 'preparing')
      SetupServerWorker.perform_in(SetupServerWorker::CHECK_INTERVAL, server_id)
    rescue => e
      server.log("Background job waiting for starting server failed: #{e}")
      server.reset_state
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
