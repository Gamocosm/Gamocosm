class AutoshutdownMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(minecraft_id, last_check_successful = true, last_check_has_players = true, times = 0)
    minecraft = Minecraft.find(minecraft_id)
    minecraft.update_columns(autoshutdown_last_check: Time.now)
    server = minecraft.server
    # the next two checks and server.remote.status are !server.running?
    if !server.remote.exists?
      return
    end
    if server.remote.error?
      minecraft.log("Error communicating with Digital Ocean while checking for autoshutdown; they responded with #{server.remote.error}")
      if !last_check_successful && times == 7
        UserMailer.autoshutdown_error_email(minecraft.user).deliver
      else
        # note: don't care about last_check_has_players
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, false, false, last_check_successful ? 1 : (times + 1))
      end
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
      if !last_check_successful && times == 7
        UserMailer.autoshutdown_error_email(minecraft.user).deliver
      else
        # note: don't care about last_check_has_players
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, false, false, last_check_successful ? 0 : (times + 1))
      end
      return
    end
    # !server.running? and the next two checks are !minecraft.running?
    if minecraft.node.error?
      # minecraft.node.error? will log if true
      minecraft.update_columns(autoshutdown_last_successful: Time.now)
      if last_check_successful && times == 7
        error = minecraft.stop
        if error
          minecraft.log("In autoshutdown worker, unable to stop server: #{error}")
          UserMailer.autoshutdown_error_email(minecraft.user).deliver
        end
      else
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, true, false, last_check_successful ? (times + 1) : 1)
      end
      return
    end
    if minecraft.node.pid == 0
      minecraft.update_columns(autoshutdown_last_successful: Time.now)
      if last_check_successful && times == 7
        error = minecraft.stop
        if error
          minecraft.log("In autoshutdown worker, unable to stop server: #{error}")
          UserMailer.autoshutdown_error_email(minecraft.user).deliver
        end
      else
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, true, false, last_check_successful ? (times + 1) : 1)
      end
      return
    end
    num_players = Minecraft::Querier.new(minecraft.server.remote.ip_address).read_num_players
    if num_players.nil?
      minecraft.log('Error pinging Minecraft server')
      if !last_check_successful && times == 7
        UserMailer.autoshutdown_error_email(minecraft.user).deliver
      else
        # note: don't care about last_check_has_players
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, false, false, last_check_successful ? 1 : (times + 1))
      end
      return
    end
    minecraft.update_columns(autoshutdown_last_successful: Time.now)
    if num_players == 0
      if last_check_successful && times == 7
        error = minecraft.stop
        if error
          minecraft.log("In autoshutdown worker, unable to stop server: #{error}")
          UserMailer.autoshutdown_error_email(minecraft.user).deliver
        end
      else
        AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, true, false, last_check_successful ? (times + 1) : 1)
      end
    else
      AutoshutdownMinecraftWorker.perform_in(64.seconds, minecraft_id, true, true, 0)
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    minecraft = Minecraft.find(minecraft_id)
    minecraft.log("Background job checking for autoshutdown failed: #{e}")
    UserMailer.autoshutdown_error_email(minecraft.user).deliver
    raise
  end

end
