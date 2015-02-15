module Mock
  class Mocker
    def mock_minecraft(minecraft)
      class << minecraft
        def node
          @node ||= Minecraft::Node.new
        end
      end
      minecraft
    end
  end

  class Server < ::Server
    def remote
      @remote ||= ServerRemote.new(self)
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

  module Minecraft
    class Node
      def pid
        1
      end
      def properties
        ::Minecraft::Properties::DEFAULT_PROPERTIES
      end
    end
  end
end
