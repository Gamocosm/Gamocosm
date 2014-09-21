class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(server_id, digital_ocean_snapshot_action_id)
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
    event = DigitalOcean::Action.new(server.remote_id, digital_ocean_snapshot_action_id, server.minecraft.user)
    if event.error?
      logger.info "Error with server #{server_id}, digital ocean snapshot event #{digital_ocean_snapshot_action_id} failed with #{event.show}"
      error = server.remote.shutdown
      if error
        logger.info "Error with server #{server_id}, unable to shutdown: #{error}"
        server.reset_partial
        return
      end
      WaitForStoppingServerWorker.perform_in(0.seconds, server_id)
      return
    elsif !event.done? || server.remote.busy?
      WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, digital_ocean_snapshot_action_id)
      return
    end
    server.update_columns(do_saved_snapshot_id: server.remote.latest_snapshot_id)
    error = server.remote.destroy
    if error
      logger.info "Error with server #{server_id}, unable to destroy server: #{error}"
    end
    server.update_columns(pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
