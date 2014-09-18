class WaitForStartingServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(user_id, droplet_id)
    droplet = Droplet.find(droplet_id)
    if droplet.remote.nil?
      logger.info "Droplet #{droplet_id} in #{self.class} remote nil"
      return
    end
    error = droplet.remote.error
    if error
      raise "Error with droplet #{droplet_id} remote: #{error}"
    end
    if droplet.remote.busy?
      WaitForStartingServerWorker.perform_in(4.seconds, user_id, droplet_id)
      return
    end
    droplet.minecraft_server.update_columns(pending_operation: 'preparing')
    WaitForSSHServerWorker.perform_in(4.seconds, user_id, droplet_id)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

end
