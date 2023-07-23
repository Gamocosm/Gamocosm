module Mock
  class Mocker
    def mock_server(server)
      class << server
        def remote
          @remote ||= ServerRemote.new(self)
        end
      end
      server
    end
  end

  class Minecraft < ::Minecraft
    def node
      @node ||= Minecraft::Node.new
    end
  end

  class ServerRemote < ::ServerRemote
    def initialize(server)
      super(server)
    end

    def sync
      @data ||= DigitalOcean::Droplet.new(1, nil, nil, nil, 'active', [], '12.34.56.78')
    end
  end

  class Minecraft::Node
    def pid
      1
    end

    def properties
      ::Minecraft::Properties::DEFAULT_PROPERTIES
    end
  end
end
