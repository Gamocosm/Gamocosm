class AutoshutdownMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(minecraft_id, last_check_successful = true, last_check_has_players = true, times = 0)
    minecraft = Minecraft.find(minecraft_id)
    server = minecraft.server
    begin
      minecraft.update_columns(autoshutdown_last_check: Time.now)
      # the next two checks and server.remote.status are !server.running?
      if !server.remote.exists?
        return
      end
      if server.remote.error?
        minecraft.log("Error communicating with Digital Ocean while checking for autoshutdown; they responded with #{server.remote.error}")
        self.handle_failure(minecraft, last_check_has_players, times)
        return
      end
      if !minecraft.autoshutdown_enabled
        return
      end
      if server.pending_operation == 'stopping' || server.pending_operation == 'saving'
        return
      end
      if server.remote.status != 'active'
        minecraft.log("Checking for autoshutdown: remote status was #{server.remote.status}; something bad happened!")
        self.handle_failure(minecraft, last_check_has_players, times)
        return
      end
      # !server.running? and the next two checks are !minecraft.running?
      if minecraft.node.error?
        # minecraft.node.error? will log if true
        self.handle_failure(minecraft, last_check_successful, times)
        return
      end
      if minecraft.node.pid == 0
        self.handle_success(minecraft, 0, last_check_successful, last_check_has_players, times)
        return
      end
      num_players = Minecraft::Querier.new(minecraft.server.remote.ip_address).read_num_players
      if num_players.nil?
        minecraft.log('Error querying Minecraft server')
        self.handle_failure(minecraft, last_check_successful, times)
        return
      end
      self.handle_success(minecraft, num_players, last_check_successful, last_check_has_players, times)
    rescue => e
      minecraft = Minecraft.find(minecraft_id)
      minecraft.log("Background job checking for autoshutdown failed: #{e}")
      UserMailer.autoshutdown_error_email(minecraft.user).deliver
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

  def handle_failure(minecraft, last_check_successful, times)
    if !last_check_successful && times == self.times_to_check_minus_one
      UserMailer.autoshutdown_error_email(minecraft).deliver
    else
      times_prime = last_check_successful ? 1 : (times + 1)
      AutoshutdownMinecraftWorker.perform_in(self.check_interval, minecraft.id, false, false, times_prime)
    end
  end

  def handle_success(minecraft, current_players, last_check_successful, last_check_has_players, times)
    minecraft.update_columns(autoshutdown_last_successful: Time.now)
    if current_players > 0
      AutoshutdownMinecraftWorker.perform_in(self.check_interval, minecraft.id, true, true, 0)
      return
    end
    if last_check_successful && times == self.times_to_check_minus_one
      error = minecraft.stop
      if error
        minecraft.log("In autoshutdown worker, unable to stop server: #{error}")
        UserMailer.autoshutdown_error_email(minecraft).deliver
      end
    else
      times_prime = last_check_successful ? (times + 1) : 1
      AutoshutdownMinecraftWorker.perform_in(self.check_interval, minecraft.id, true, false, times_prime)
    end
  end

  def times_to_check_minus_one
    return Rails.env.test? ? 3 : 7
  end

  def check_interval
    return Rails.env.test? ? 4.seconds : 64.seconds
  end

end
