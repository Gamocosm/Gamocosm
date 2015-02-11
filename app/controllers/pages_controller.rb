class PagesController < ApplicationController
  def landing
    @nocontainer = true
  end

  def about
  end

  def info
  end

  def tos
  end

  def digital_ocean_setup
  end

  def demo
    @minecraft = Minecraft.new
    server = Server.new
    server.do_region_slug = 'nyc3'
    server.do_size_slug = '1gb'
    server.remote_setup_stage = 5
    server.server_domain = ServerDomain.new
    server.server_domain.name = 'abcdefgh'
    def server.busy?
      return false
    end
    def server.remote
      if @minecraft_server_remote.nil?
        r = Hashie::Mash.new
        r.ip_address = '12.34.56.78'
        r.status = 'active'
        r.exists = true
        @minecraft_server_remote = r
      end
      return @minecraft_server_remote
    end
    def server.running?
      return true
    end
    def @minecraft.running?
      return true
    end
    def @minecraft.node
      if @minecraft_node.nil?
        node = Minecraft::Node.new(self, '12.34.56.78')
        def node.properties
          return Minecraft::Properties::DEFAULT_PROPERTIES
        end
        @minecraft_node = node
      end
      return @minecraft_node
    end
    def @minecraft.properties
      if @minecraft_properties.nil?
        @minecraft_properties = Minecraft::Properties.new(self)
      end
      return @minecraft_properties
    end
    @minecraft.server = server
    @minecraft.autoshutdown_enabled = true
    @minecraft.autoshutdown_last_check = Time.now - 32.seconds
    @minecraft.autoshutdown_last_successful = Time.now - 32.seconds
    @demo = true
  end

  def not_found
    render status: 404
  end

  def unacceptable
    render status: 422
  end

  def internal_error
    render status: 500
  end

  def badness
    if params[:secret] == ENV['BADNESS_SECRET']
      do_bad_things
    end
    return redirect_to root_path
  end
end
