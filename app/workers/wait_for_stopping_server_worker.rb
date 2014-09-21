class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(server_id)
    server = Server.find(server_id)
    if !server.remote.exists?
      logger.info "Server #{server_id} in #{self.class} remote doesn't exist (remote_id nil)"
      server.reset
      return
    end
    if server.remote.error?
      logger.info "Error with server #{server} remote: #{server.remote.error}"
      server.reset
      return
    end
    if server.remote.busy?
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    end
    if server.remote.status != 'off'
      logger.warn "Server #{server_id} in WaitForStoppingServerWorker not busy but status off, was #{server.remote.status}"
      error = server.remote.shutdown
      if error
        logger.info "Error with server #{server_id}, unable to shutdown; #{error}"
        server.reset_partial
        return
      end
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    end
    error = server.remote.snapshot
    if error
      logger.info "Error with server #{server_id}, unable to snapshot; #{error}"
      server.reset_partial
      return
    end
    server.update_columns(pending_operation: 'saving')
    WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, server.remote.snapshot_action_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
