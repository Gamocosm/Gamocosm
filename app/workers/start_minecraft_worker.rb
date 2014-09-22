class StartMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(server_id)
    server = Server.find(server_id)
    minecraft = server.minecraft
    if !server.remote.exists?
      minecraft.log('Error starting server; remote_id is nil. Aborting')
      server.reset
      return
    end
    if server.remote.error?
      minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
      server.reset
      return
    end
    error = minecraft.node.resume
    if error
      minecraft.log("Error starting Minecraft on server: #{error}")
    end
    connection = minecraft.user.digital_ocean
    if connection
      response = connection.image.destroy(minecraft.server.do_saved_snapshot_id)
      if !response.success?
        minecraft.log("Error deleting saved snapshot on Digital Ocean after starting server; they responded with #{response}")
      end
    end
    minecraft.server.update_columns(pending_operation: nil, do_saved_snapshot_id: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end
