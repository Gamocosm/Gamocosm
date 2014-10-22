class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    if times > 32
      server.minecraft.log("Still waiting for Digital Ocean server to snapshot, tried #{times} times")
    elsif times > 64
      server.minecraft.log('Digital Ocean took too long to snapshot server. Aborting')
      server.reset_partial
      return
    end
    if !server.remote.exists?
      server.minecraft.log('Error stopping server; remote_id is nil. Aborting')
      server.reset_partial
      return
    end
    if server.remote.error?
      server.minecraft.log("Error communicating with Digital Ocean while stopping server; they responded with #{server.remote.error}. Aborting")
      server.reset_partial
      return
    end
    event = DigitalOcean::Action.new(server.remote_id, digital_ocean_action_id, server.minecraft.user)
    if event.error?
      server.minecraft.log("Error with Digital Ocean snapshot server action #{digital_ocean_action_id}; they responded with #{event.show}. Aborting")
      server.reset_partial
      return
    elsif !event.done?
      WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, digital_ocean_action_id, times + 1)
      return
    end
    snapshot_id = server.remote.latest_snapshot_id
    if snapshot_id.nil?
      server.minecraft.log('Finished snapshotting server on Digital Ocean, but unable to get latest snapshot id. Aborting')
      server.reset_partial
      return
    end
    server.update_columns(do_saved_snapshot_id: snapshot_id)
    error = server.remote.destroy
    if error
      server.minecraft.log("Error destroying server on Digital Ocean (has been snapshotted and saved); #{error}")
    end
    server.update_columns(pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job waiting for snapshotting server failed: #{e}")
    server.reset_partial
    raise
  end

end
