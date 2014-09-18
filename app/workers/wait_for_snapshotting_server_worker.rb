class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(droplet_id, digital_ocean_snapshot_action_id)
    droplet = Droplet.find(droplet_id)
    if droplet.remote.nil?
      logger.info "Droplet #{droplet_id} in #{self.class} remote nil"
      return
    end
    error = droplet.remote.error
    if droplet.remote.error
      raise "Error with droplet #{droplet_id} remote: #{error}"
    end
    event = DigitalOcean::DropletAction.new(droplet.remote_id, digital_ocean_snapshot_action_id, droplet.minecraft_server.user)
    if event.has_error?
      logger.info "Error with droplet #{droplet_id}, digital ocean snapshot event #{digital_ocean_snapshot_action_id} failed with #{event.show}"
      WaitForStoppingServerWorker.perform_in(0.seconds, droplet_id)
      return
    elsif !event.is_done? || droplet.remote.busy?
      WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id, digital_ocean_snapshot_action_id)
      return
    end
    droplet.minecraft_server.update_columns(saved_snapshot_id: event.resource_id)
    error = droplet.remote.destroy
    if error
      raise error
    end
    droplet.minecraft_server.update_columns(pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
