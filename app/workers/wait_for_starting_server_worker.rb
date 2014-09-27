class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, server_id)
    server = Server.find(server_id)
    if !server.remote.exists?
      server.minecraft.log('Error starting server; remote_id is nil. Aborting')
      server.reset
      return
    end
    if server.remote.error?
      server.minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
      server.reset
      return
    end
    if server.remote.busy?
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, server_id)
      return
    end
    if server.remote.status != 'active'
      server.minecraft.log("Server told to start, not busy anymore, but status not on, was #{server.remote.status}")
      error = server.remote.power_on
      if error
        server.minecraft.log("Error powering on server on Digital Ocean; #{error}. Aborting")
        error = server.remote.destroy
        if error
          server.minecraft.log("Error destroying server on Digital Ocean after failed to power on; #{error}. (Aborting)")
        end
        server.reset_partial
        return
      end
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, server_id)
      return
    end
    server.update_columns(pending_operation: 'preparing')
    WaitForSSHServerWorker.perform_in(4.seconds, user_id, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
