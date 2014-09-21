class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, server_id)
    server = Server.find(server_id)
    if !server.remote.exists?
      logger.info "Server #{server_id} in #{self.class} remote doesn't exist (remote_id nil)"
      server.reset
      return
    end
    if server.remote.error?
      logger.info "Error with server #{server_id} remote: #{server.remote.error}"
      server.reset
      return
    end
    if server.remote.busy?
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, server_id)
      return
    end
    server.update_columns(pending_operation: 'preparing')
    WaitForSSHServerWorker.perform_in(4.seconds, user_id, server_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
