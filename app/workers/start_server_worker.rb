class StartServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(minecraft_server_id)
    minecraft_server = MinecraftServer.find(minecraft_server_id)
    if !minecraft_server.resume
      logger.warn "StartServerWorker#perform: minecraft server #{minecraft_server_id} unable to resume"
    end
    connection = minecraft_server.user.digital_ocean
    if connection
      connection.image.destroy(minecraft_server.saved_snapshot_id)
    end
    minecraft_server.update_columns(remote_setup_stage: 1, pending_operation: nil, saved_snapshot_id: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end


