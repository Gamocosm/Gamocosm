class StartMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id)
    server = Server.find(server_id)
    minecraft = server.minecraft
    user = minecraft.user
    begin
      if user.digital_ocean_missing?
        server.minecraft.log('Error starting server; you have not entered your Digital Ocean API token. Aborting')
        server.reset_partial
        return
      end
      if !server.remote.exists?
        minecraft.log('Error starting server; remote_id is nil. Aborting')
        server.reset_partial
        return
      end
      if server.remote.error?
        minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
        server.reset_partial
        return
      end
      error = minecraft.node.resume
      if error
        minecraft.log("Error starting Minecraft on server: #{error}")
      end
      error = minecraft.server.remote.destroy_saved_snapshot
      if error
        minecraft.log("Error deleting saved snapshot on Digital Ocean after starting server; #{error}")
      end
      if minecraft.autoshutdown_enabled
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft.id)
      end
      server.update_columns(pending_operation: nil)
    rescue => e
      server = Server.find(server_id)
      server.minecraft.log("Background job starting Minecraft failed: #{e}")
      server.reset_partial
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end
