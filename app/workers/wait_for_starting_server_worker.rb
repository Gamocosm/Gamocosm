class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, droplet_id)
    user = User.find(user_id)
    droplet = Droplet.find(droplet_id)
    error = droplet.remote.error
    if error
      raise "Error with droplet #{droplet_id} remote: #{error}"
    end
    if droplet.remote.busy?
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, droplet_id)
      return
    end
    user.digital_ocean.image.destroy(droplet.minecraft_server.saved_snapshot_id)
    droplet.minecraft_server.update_columns(pending_operation: 'preparing', saved_snapshot_id: nil)
    WaitForSSHServerWorker.perform_in(4.seconds, user_id, droplet_id)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.info "Record in #{self.class} not found #{e.message}"
  end

end
