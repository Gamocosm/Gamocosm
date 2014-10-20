class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  sidekiq_retries_exhausted do |msg|
    args = msg['args']
    server = Server.find(args[1])
    server.minecraft.log("Background job waiting for starting server died: #{msg['error_message']}")
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
    if server.remote.status != 'active'
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, server_id)
      return
    end
    server.update_columns(pending_operation: 'preparing')
    WaitForSSHServerWorker.perform_in(4.seconds, user_id, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job waiting for starting server failed: #{e}")
    raise
  end

end
