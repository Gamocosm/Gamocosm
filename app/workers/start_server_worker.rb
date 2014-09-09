class StartServerWorker
  include Sidekiq::Worker
  sidekiq_options retry: 4
  sidekiq_retry_in do |count|
    4
  end

  def perform(minecraft_server_id)
    minecraft_server = MinecraftServer.find(minecraft_server_id)
    if !minecraft_server.resume
      Rails.logger.warn "StartServerWorker#perform: minecraft server #{minecraft_server_id} unable to resume"
    end
    minecraft_server.update_columns(remote_setup_stage: 1, pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.info "Record in #{self.class} not found #{e.message}"
  end
end


