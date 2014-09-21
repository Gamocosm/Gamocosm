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
      logger.info "Server #{server_id} in #{self.class} remote doesn't exist (remote_id nil)"
      server.reset
      return
    end
    if server.remote.error?
      logger.info "Server #{server_id} in #{self.class} remote had error #{server.remote.error}"
      server.reset
      return
    end
    if !minecraft.node.resume
      logger.warn "StartMinecraftWorker#perform: minecraft #{minecraft.id} unable to resume"
    end
    connection = minecraft.user.digital_ocean
    if connection
      response = connection.image.destroy(minecraft.server.do_saved_snapshot_id)
      if !response.success?
        # TODO: log to user
      end
    end
    minecraft.server.update_columns(pending_operation: nil, do_saved_snapshot_id: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end
end
