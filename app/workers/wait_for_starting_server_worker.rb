class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(user_id, server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    begin
      if times > 64
        server.minecraft.log('Digital Ocean took too long to start server. Aborting')
        server.reset_partial
        return
      elsif times > 32
        server.minecraft.log("Still waiting for Digital Ocean server to start, tried #{times} times")
      end
      if !server.remote.exists?
        server.minecraft.log('Error starting server; remote_id is nil. Aborting')
        server.reset_partial
        return
      end
      if server.remote.error?
        server.minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
        server.reset_partial
        return
      end
      server.refresh_domain
      event = DigitalOcean::Action.new(server.remote_id, digital_ocean_action_id, server.minecraft.user)
      if event.error?
        server.minecraft.log("Error with Digital Ocean start server action #{digital_ocean_action_id}; they responded with #{event.show}. Aborting")
        server.reset_partial
        return
      elsif !event.done?
        WaitForStartingServerWorker.perform_in(4.seconds, user_id, server_id, digital_ocean_action_id, times + 1)
        return
      end
      if server.remote.status != 'active'
        server.minecraft.log("Finished starting server on Digital Ocean, but remote status was #{server.remote.status} (not 'active'). Aborting")
        server.reset_partial
        return
      end
      server.update_columns(pending_operation: 'preparing')
      SetupServerWorker.perform_in(4.seconds, user_id, server_id)
    rescue => e
      server = Server.find(server_id)
      server.minecraft.log("Background job waiting for starting server failed: #{e}")
      server.reset_partial
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
