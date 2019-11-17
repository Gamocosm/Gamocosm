class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    user = server.user
    begin
      if !server.remote.exists?
        server.log('Error snapshotting server; remote_id is nil. Aborting')
        server.reset_state
        return
      end
      if server.remote.error?
        server.log("Error communicating with Digital Ocean while snapshotting server: #{server.remote.error}. Aborting")
        server.reset_state
        return
      end
      event = user.digital_ocean.droplet_action_show(server.remote_id, digital_ocean_action_id)
      if event.error?
        server.log("Error with Digital Ocean snapshot server action #{digital_ocean_action_id}; #{event}. Aborting")
        server.reset_state
        user.invalidate_digital_ocean_cache_snapshots
        return
      elsif event.failed?
        server.log("Snapshotting server on Digital Ocean failed: #{event}. Aborting")
        server.reset_state
        return
      elsif !event.done?
        times += 1
        if times >= 32 && times % 8 == 0
          server.log("Still waiting for Digital Ocean server to snapshot, tried #{times} times")
        end
        if times >= 1024
          server.log('Digital Ocean took too long to snapshot server. Aborting')
          server.reset_state
          return
        end
        WaitForSnapshottingServerWorker.perform_in(4.seconds, server_id, digital_ocean_action_id, times)
        return
      end
      user.invalidate_digital_ocean_cache_snapshots
      snapshot_id = server.remote.latest_snapshot_id
      if snapshot_id.nil?
        server.log('Finished snapshotting server on Digital Ocean, but unable to get latest snapshot id. Aborting')
        server.reset_state
        return
      end
      server.update_columns(remote_snapshot_id: snapshot_id)
      error = server.remote.destroy
      if error
        server.log("Error destroying server on Digital Ocean (has been snapshotted and saved); #{error}")
      end
      user.invalidate_digital_ocean_cache_droplets
      server.update_columns(pending_operation: nil)
    rescue => e
      server.log("Background job waiting for snapshotting server failed: #{e}")
      server.reset_state
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
