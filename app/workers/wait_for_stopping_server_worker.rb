class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    user = server.user
    begin
      if !server.remote.exists?
        server.log('Error stopping server; remote_id is nil. Aborting')
        server.reset_state
        return
      end
      if server.remote.error?
        server.log("Error communicating with Digital Ocean while stopping server: #{server.remote.error}. Aborting")
        server.reset_state
        return
      end
      event = user.digital_ocean.droplet_action_show(server.remote_id, digital_ocean_action_id)
      if event.error?
        server.log("Error with Digital Ocean stop server action #{digital_ocean_action_id}; #{event}. Aborting")
        server.reset_state
        return
      elsif event.failed?
        server.log("Stopping server on Digital Ocean failed: #{event}. Aborting")
        server.reset_state
        return
      elsif !event.done? || server.remote.status != 'off'
        times += 1
        if times >= 32
          server.log('Digital Ocean took too long to stop server. Aborting')
          server.reset_state
          return
        elsif times >= 16
          server.log("Still waiting for Digital Ocean server to stop, tried #{times} times")
        end
        WaitForStoppingServerWorker.perform_in(4.seconds, server_id, digital_ocean_action_id, times)
        return
      end
      action = server.remote.snapshot
      if action.error?
        server.log("Error snapshotting server on Digital Ocean; #{action}. Aborting")
        server.reset_state
        return
      end
      server.update_columns(pending_operation: 'saving')
      WaitForSnapshottingServerWorker.perform_in(16.seconds, server_id, action.id)
    rescue => e
      server.log("Background job waiting for stopping server failed: #{e}")
      server.reset_state
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
