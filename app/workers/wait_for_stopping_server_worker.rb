class WaitForStoppingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(droplet_id)
    droplet = Droplet.find(droplet_id)
    error = droplet.remote.error
    if error
      raise "Error with droplet #{droplet_id} remote: #{error}"
    end
    if droplet.remote.busy?
      WaitForStoppingServerWorker.perform_in(4.seconds, droplet_id)
      return
    end
    if droplet.remote.status != 'off'
      Rails.logger.warn "Droplet #{droplet_id} in WaitForStoppingServerWorker not busy but status off, was #{droplet.remote.status}"
      error = droplet.remote.shutdown
      if error
        raise error
      end
      WaitForStoppingServerWorker.perform_in(4.seconds, droplet_id)
      return
    end
    error = droplet.remote.snapshot
    if error
      raise error
    end
    droplet.minecraft_server.update_columns(pending_operation: 'saving')
    WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id, droplet.remote.snapshot_action_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.info "Record in #{self.class} not found #{e.message}"
  end

end
