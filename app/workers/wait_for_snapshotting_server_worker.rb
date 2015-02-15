class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(user_id, server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    user = User.find(user_id)
    begin
      if user.digital_ocean_missing?
        server.minecraft.log('Error starting server; you have not entered your Digital Ocean API token. Aborting')
        server.reset_partial
        return
      end
      if !server.remote.exists?
        server.minecraft.log('Error snapshotting server; remote_id is nil. Aborting')
        server.reset_partial
        return
      end
      if server.remote.error?
        server.minecraft.log("Error communicating with Digital Ocean while snapshotting server; they responded with #{server.remote.error}. Aborting")
        server.reset_partial
        return
      end
      event = user.digital_ocean.droplet_action_show(server.remote_id, digital_ocean_action_id)
      if event.error?
        server.minecraft.log("Error with Digital Ocean snapshot server action #{digital_ocean_action_id}; #{event}. Aborting")
        server.reset_partial
        user.invalidate
        return
      elsif event.failed?
        server.minecraft.log("Snapshotting server on Digital Ocean failed: #{event}. Aborting")
        server.reset_partial
        return
      elsif !event.done?
        times += 1
        if times >= 64
          server.minecraft.log('Digital Ocean took too long to snapshot server. Aborting')
          server.reset_partial
          return
        elsif times >= 32
          server.minecraft.log("Still waiting for Digital Ocean server to snapshot, tried #{times} times")
        end
        WaitForSnapshottingServerWorker.perform_in(4.seconds, user_id, server_id, digital_ocean_action_id, times)
        return
      end
      user.invalidate
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
    rescue => e
      server = Server.find(server_id)
      server.minecraft.log("Background job waiting for snapshotting server failed: #{e}")
      server.reset_partial
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
