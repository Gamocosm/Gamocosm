class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  sidekiq_retries_exhausted do |msg|
    args = msg['args']
    server = Server.find(args[0])
    server.minecraft.log("Background job waiting for stopping server died: #{msg['error_message']}")
  end

  def perform(server_id)
    server = Server.find(server_id)
    if !server.remote.exists?
      server.minecraft.log('Error stopping server; remote_id is nil. Aborting')
      server.reset
      return
    end
    if server.remote.error?
      server.minecraft.log("Error communicating with Digital Ocean while stopping server; they responded with #{server.remote.error}. Aborting")
      server.reset
      return
    end
    if server.remote.status != 'off'
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    end
    error = server.remote.snapshot
    if error
      server.minecraft.log("Error snapshotting server on Digital Ocean; #{error}. Aborting")
      server.reset_partial
      return
    end
    server.update_columns(pending_operation: 'saving')
    WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, server.remote.action_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job waiting for stopping server failed: #{e}")
    raise
  end

end
