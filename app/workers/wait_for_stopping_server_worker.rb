class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id, digital_ocean_action_id, times = 0)
    server = Server.find(server_id)
    if times > 16
      server.minecraft.log("Still waiting for Digital Ocean server to stop, tried #{times} times")
    elsif times > 32
      server.minecraft.log('Digital Ocean took too long to stop server. Aborting')
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
      server.minecraft.log("Error with Digital Ocean stop server action #{digital_ocean_action_id}; they responded with #{event.show}. Aborting")
      server.reset_partial
      return
    elsif !event.done?
      WaitForStoppingServerWorker.perform_in(4.seconds, server_id, digital_ocean_action_id, times + 1)
      return
    end
    if server.remote.status != 'off'
      server.minecraft.log("Finished stopping server on Digital Ocean, but remote status was #{server.remote.status} (not 'off'). Aborting")
      server.reset_partial
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
    server.reset_partial
    raise
  end

end
