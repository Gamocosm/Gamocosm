class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(user_id, server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    user = User.find(user_id)
    begin
      if !server.remote.exists?
        server.minecraft.log('Error stopping server; remote_id is nil. Aborting')
        server.reset_partial
        return
      end
      if server.remote.error?
        server.minecraft.log("Error communicating with Digital Ocean while stopping server: #{server.remote.error}. Aborting")
        server.reset_partial
        return
      end
      event = user.digital_ocean.droplet_action_show(server.remote_id, digital_ocean_action_id)
      if event.error?
        server.minecraft.log("Error with Digital Ocean stop server action #{digital_ocean_action_id}; #{event}. Aborting")
        server.reset_partial
        return
      elsif event.failed?
        server.minecraft.log("Stopping server on Digital Ocean failed: #{event}. Aborting")
        server.reset_partial
        return
      elsif !event.done?
        times += 1
        if times >= 32
          server.minecraft.log('Digital Ocean took too long to stop server. Aborting')
          server.reset_partial
          return
        elsif times >= 16
          server.minecraft.log("Still waiting for Digital Ocean server to stop, tried #{times} times")
        end
        WaitForStoppingServerWorker.perform_in(4.seconds, user_id, server_id, digital_ocean_action_id, times)
        return
      end
      if server.remote.status != 'off'
        server.minecraft.log("Finished stopping server on Digital Ocean, but remote status was #{server.remote.status} (not 'off'). Aborting")
        server.reset_partial
        return
      end
      action = server.remote.snapshot
      if action.error?
        server.minecraft.log("Error snapshotting server on Digital Ocean; #{action}. Aborting")
        server.reset_partial
        return
      end
      server.update_columns(pending_operation: 'saving')
      WaitForSnapshottingServerWorker.perform_in(4.seconds, user_id, server_id, action.id)
    rescue => e
      server = Server.find(server_id)
      server.minecraft.log("Background job waiting for stopping server failed: #{e}")
      server.reset_partial
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
