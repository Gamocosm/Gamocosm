class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(server_id)
    server = Server.find(server_id)
    minecraft = server.minecraft
    if !server.remote.exists?
      minecraft.log('Error stopping server; remote_id is nil. Aborting')
      server.reset
      return
    end
    if server.remote.error?
      minecraft.log("Error communicating with Digital Ocean while stopping server; they responded with #{server.remote.error}. Aborting")
      server.reset
      return
    end
    if server.remote.busy?
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    end
    if server.remote.status != 'off'
      minecraft.log("Server told to shutdown, not busy anymore, but status not off, was #{server.remote.status}")
      error = server.remote.shutdown
      if error
        minecraft.log("Error shutting down server on Digital Ocean; they responded with #{error}. Aborting")
        server.reset_partial
        return
      end
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    end
    error = server.remote.snapshot
    if error
      logger.info "Error with server #{server_id}, unable to snapshot; #{error}"
      minecraft.log("Error snapshotting server on Digital Ocean; they responded with #{error}. Aborting")
      server.reset_partial
      return
    end
    server.update_columns(pending_operation: 'saving')
    WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, server.remote.snapshot_action_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
