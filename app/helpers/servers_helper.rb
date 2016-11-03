module ServersHelper
  def server_status_class(server)
    if server.pending_operation
      'text-warning'
    elsif server.remote.error?
      'text-danger'
    elsif server.running?
      'text-success'
    else
      'text-muted'
    end
  end

  def server_minecraft_status_class(server)
    if server.minecraft.pause?.nil?
      'text-success'
    else
      'text-muted'
    end
  end
end
