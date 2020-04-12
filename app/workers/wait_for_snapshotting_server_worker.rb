class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  CHECK_INTERVAL = Rails.env.test? ? 2.seconds : 8.seconds

  def perform(server_id, digital_ocean_action_id, times = 0, log_success = false)
    logger.info "Running #{self.class.name} with server_id #{server_id}, times #{times}"
    server = Server.find(server_id)
    user = server.user
    times += 1
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
        if times >= 1024
          server.log('Digital Ocean took too long to snapshot server. Aborting')
          server.reset_state
          return
        elsif times >= 32 && times % 8 == 0
          server.log("Still waiting for Digital Ocean server to snapshot, tried #{times} times")
          log_success = true
        end
        WaitForSnapshottingServerWorker.perform_in(CHECK_INTERVAL, server_id, digital_ocean_action_id, times, log_success)
        return
      end
      user.invalidate_digital_ocean_cache_snapshots
      snapshot_id = server.remote.latest_snapshot_id
      if snapshot_id.nil?
        if times >= 256
          server.log('Finished snapshotting server on Digital Ocean, but unable to get latest snapshot id. Aborting')
          server.reset_state
        else
          server.log("Finished snapshotting server on Digital Ocean, but unable to get latest snapshot id. Trying again (tried #{times} times)")
          WaitForSnapshottingServerWorker.perform_in(CHECK_INTERVAL, server_id, digital_ocean_action_id, times, true)
        end
        return
      end
      if log_success
        server.log('Finished snapshotting server on Digital Ocean and got snapshot ID')
      end
      error = server.remote.destroy_saved_snapshot
      if error
        server.log("Error deleting old saved snapshot on Digital Ocean (have new snapshot): #{error}")
      end
      server.update_columns(remote_snapshot_id: snapshot_id)
      error = server.remote.destroy
      if error
        server.log("Error destroying server on Digital Ocean (has been snapshotted and saved): #{error}")
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
