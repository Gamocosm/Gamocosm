class StartMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id)
    # see AutoshutdownMinecraftWorker for explanation of the next two lines
    minecraft = Minecraft.find_by!(server_id: server_id)
    server = minecraft.server
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
      error = minecraft.node.resume
      if error
        server.log("Error starting Minecraft on server: #{error}")
      end
      error = minecraft.server.remote.destroy_saved_snapshot
      if error
        server.log("Error deleting saved snapshot on Digital Ocean after starting server; #{error}")
      end
      if minecraft.autoshutdown_enabled
        AutoshutdownMinecraftWorker.perform_in(64.seconds, server_id)
      end
      server.update_columns(pending_operation: nil)
    rescue => e
      server.log("Background job starting Minecraft failed: #{e}")
      server.reset_state
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end
