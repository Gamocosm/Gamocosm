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

  def breadcrumb_back_to_servers
    link_to servers_path, class: "basic-breadcrumb" do
      "Servers <span class='fa fa-angle-right'></span>".html_safe
    end
  end
end
