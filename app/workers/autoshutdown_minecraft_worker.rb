class AutoshutdownMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  TIMES_TO_CHECK_MINUS_ONE = Rails.env.test? ? 2 : 7
  CHECK_INTERVAL = 64.seconds

  def perform(minecraft_id, last_check_successful = true, last_check_has_players = true, times = 0)
    minecraft = Minecraft.find(minecraft_id)
    server = minecraft.server
    user = minecraft.user
    begin
      minecraft.update_columns(autoshutdown_last_check: Time.now)
      # the next two checks and server.remote.status are !server.running?
      if !server.remote.exists?
        return
      end
      if server.remote.error?
        minecraft.log("Error communicating with Digital Ocean while checking for autoshutdown: #{server.remote.error}")
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
        self.handle_failure(minecraft, last_check_successful, times)
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
      minecraft.log("Background job checking for autoshutdown failed: #{e}")
      UserMailer.autoshutdown_error_email(minecraft.user).deliver_now
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

  def handle_failure(minecraft, last_check_successful, times)
    if !last_check_successful && times == TIMES_TO_CHECK_MINUS_ONE
      UserMailer.autoshutdown_error_email(minecraft).deliver_now
    else
      times_prime = last_check_successful ? 1 : (times + 1)
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, minecraft.id, false, false, times_prime)
    end
  end

  def handle_success(minecraft, current_players, last_check_successful, last_check_has_players, times)
    minecraft.update_columns(autoshutdown_last_successful: Time.now)
    if current_players > 0
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, minecraft.id, true, true, 0)
      return
    end
    if last_check_successful && times == TIMES_TO_CHECK_MINUS_ONE
      error = minecraft.stop
      if error
        minecraft.log("In autoshutdown worker, unable to stop server: #{error}")
        UserMailer.autoshutdown_error_email(minecraft).deliver_now
      end
    else
      times_prime = last_check_successful ? (times + 1) : 1
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, minecraft.id, true, false, times_prime)
    end
  end

end
