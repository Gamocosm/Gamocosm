class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  sidekiq_retries_exhausted do |msg|
    args = msg['args']
    server = Server.find(args[0])
    server.minecraft.log("Background job waiting for snapshotting server died: #{msg['error_message']}")
  end

  def perform(server_id, digital_ocean_snapshot_action_id)
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
    event = DigitalOcean::Action.new(server.remote_id, digital_ocean_snapshot_action_id, server.minecraft.user)
    if event.error?
      server.minecraft.log("Error with Digital Ocean snapshotting server action #{digital_ocean_snapshot_action_id}; they responded with #{event.show}")
      error = server.remote.shutdown
      if error
        server.minecraft.log("Error shutting down server on Digital Ocean; #{error}. Aborting")
        server.reset_partial
        return
      end
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id)
      return
    elsif !event.done?
      WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, digital_ocean_snapshot_action_id)
      return
    end
    server.update_columns(do_saved_snapshot_id: server.remote.latest_snapshot_id)
    error = server.remote.destroy
    if error
      server.minecraft.log("Error destroying server on Digital Ocean (has been snapshotted and saved); #{error}")
    end
    server.update_columns(pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job waiting for snapshotting server failed: #{e}")
    raise
  end

end
