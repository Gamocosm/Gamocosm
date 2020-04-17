class AutoshutdownMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  CHECK_INTERVAL = Rails.env.test? ? 2.seconds : 60.seconds

  # if `last_check_successful` is false, `last_check_has_players` is also false, though its value doesn't matter
  # `times` is the number of consecutive times we got the previous check's result
  # e.g. if `last_check_successful = true`, `last_check_has_players = false`, `times = 2`,
  # it means we've already seen that 2 times (and this may be the third)
  #
  # let `n = minecraft.autoshutdown_minutes`
  # possible states for `last_check_successful`, `last_check_has_players`, `times`:
  # - true, true, 0
  # - true, false, in [1, n]
  # - false, false (doesn't matter), in [1, n]
  #
  # so:
  # - `!last_check_successful` implies `!last_check_has_players`
  # - `last_check_has_players` implies `last_check_successful` and `times == 0`
  def perform(server_id, last_check_successful = true, last_check_has_players = true, times = 0)
    logger.info "Running #{self.class.name} with server_id #{server_id}, #{last_check_successful}, #{last_check_has_players}, #{times}"
    # with models A has_one B, B belongs_to A
    # a.b.a.object_id != a.object_id
    # but
    # b.a.b.object_id == b.object_id
    # in this case, if we find the Server object first, minecraft.server will return a new Server object
    minecraft = Minecraft.find_by!(server_id: server_id)
    server = minecraft.server
    begin
      minecraft.update_columns(autoshutdown_last_check: Time.now)
      if !minecraft.autoshutdown_enabled
        return
      end
      if server.pending_operation == 'stopping' || server.pending_operation == 'saving'
        return
      end
      # the next two checks and server.remote.status are !server.running?
      if !server.remote.exists?
        return
      end
      if server.remote.error?
        server.log("Error communicating with Digital Ocean while checking for autoshutdown: #{server.remote.error}")
        self.handle_failure(server, last_check_successful, times)
        return
      end
      if server.remote.status != 'active'
        server.log("Checking for autoshutdown: remote status was #{server.remote.status}; something bad happened!")
        self.handle_failure(server, last_check_successful, times)
        return
      end
      # !server.running? and the next two checks are !minecraft.running?
      if minecraft.node.error?
        # minecraft.node.error? will log if true
        self.handle_failure(server, last_check_successful, times)
        return
      end
      if minecraft.node.pid == 0
        self.handle_success(server, 0, last_check_successful, last_check_has_players, times)
        return
      end
      num_players = minecraft.node.num_players
      if num_players.error?
        server.log(num_players.msg)
        self.handle_failure(server, last_check_successful, times)
        return
      end
      self.handle_success(server, num_players, last_check_successful, last_check_has_players, times)
    rescue => e
      server.log("Background job checking for autoshutdown failed: #{e}")
      UserMailer.autoshutdown_error_email(server).deliver_now
      raise
    end
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  end

  def handle_failure(server, last_check_successful, times)
    logger.debug "#{self.class.name} handling failure: #{server.id}, #{last_check_successful}, #{times}"
    if last_check_successful
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, false, false, 1)
    else
      if times == server.minecraft.autoshutdown_minutes
        UserMailer.autoshutdown_error_email(server).deliver_now
      else
        AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, false, false, times + 1)
      end
    end
  end

  def handle_success(server, current_players, last_check_successful, last_check_has_players, times)
    logger.debug "#{self.class.name} handling success: #{server.id}, #{current_players}, #{last_check_successful}, #{last_check_has_players}, #{times}"
    server.minecraft.update_columns(autoshutdown_last_successful: Time.now)
    if current_players > 0
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, true, true, 0)
      return
    end
    if last_check_successful
      if last_check_has_players
        AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, true, false, 1)
      else
        if times == server.minecraft.autoshutdown_minutes
          error = server.stop
          if error
            server.log("In autoshutdown worker, unable to stop server: #{error}")
            UserMailer.autoshutdown_error_email(server).deliver_now
          end
        else
          AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, true, false, times + 1)
        end
      end
    else
      AutoshutdownMinecraftWorker.perform_in(CHECK_INTERVAL, server.id, true, false, 1)
    end
  end

end
