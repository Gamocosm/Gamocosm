class WaitForSnapshottingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(droplet_id)
    droplet = Droplet.find(droplet_id)
    error = droplet.remote.error
    if droplet.remote.error
      raise "Error with droplet #{droplet_id} remote: #{error}"
    end
    if droplet.remote.busy?
      WaitForSnapshottingServerWorker.perform_in(4.seconds, droplet_id)
      return
    end
    snapshots = droplet.remote.list_snapshots
    droplet.minecraft_server.update_columns(saved_snapshot_id: snapshots[-1])
    error = droplet.remote.destroy
    if error
      raise error
    end
    droplet.minecraft_server.update_columns(pending_operation: nil)
    droplet.destroy
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.info "Record in #{self.class} not found #{e.message}"
  end

end
