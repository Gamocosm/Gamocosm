class MinecraftServer::Properties
  include ActiveModel::Model

  attr_accessor :allow_flight,
    :allow_nether,
    :announce_player_achievements,
    :difficulty,
    :enable_command_block,
    :force_gamemode,
    :gamemode,
    :generate_structures,
    :generator_settings,
    :hardcore,
    :level_seed,
    :level_type,
    :max_build_height,
    :motd,
    :online_mode,
    :op_permission_level,
    :player_idle_timeout,
    :pvp,
    :spawn_animals,
    :spawn_monsters,
    :spawn_npcs,
    :spawn_protection,
    :white_list
  attr_accessor :whitelist, :ops

  def initialize(minecraft_server)
    @minecraft_server = minecraft_server
    if @minecraft_server.node.nil?
      # TODO: error
      return
    end
    response = @minecraft_server.node.properties
    if response.nil?
      # TODO: error
      return
    end
    refresh_properties(response)
=begin
    response = @minecraft_server.node.ops
    if response.nil?
      # TODO: error
      return
    end
    self.ops = response
    response = @minecraft_server.node.whitelist
    if response.nil?
      # TODO: error
      return
    end
    self.whitelist = response
=end
  end

  def refresh_properties(response)
    self.allow_flight = response['allow-flight']
    self.allow_nether = response['allow-nether']
    self.announce_player_achievements = response['allow-player-achievements']
    self.difficulty = response['difficulty']
    self.enable_command_block = response['enable-command-block']
    self.force_gamemode = response['force-gamemode']
    self.gamemode = response['gamemode']
    self.generate_structures = response['generate-structures']
    self.generator_settings = response['generator-settings']
    self.hardcore = response['hardcore']
    self.level_seed = response['level-seed']
    self.level_type = response['level-type']
    self.max_build_height = response['max-build-height']
    self.motd = response['motd']
    self.online_mode = response['online-mode']
    self.op_permission_level = response['op-permission-level']
    self.player_idle_timeout = response['player-idle-timeout']
    self.pvp = response['pvp']
    self.spawn_animals = response['spawn-animals']
    self.spawn_monsters = response['spawn-monsters']
    self.spawn_npcs = response['spawn-npcs']
    self.spawn_protection = response['spawn-protection']
    self.white_list = response['white-list']
  end

  def update(properties)
    if @minecraft_server.node.nil?
      # TODO: error
      return false
    end
    response = @minecraft_server.node.update_properties(properties)
    if response.nil?
      # TODO: error
      return false
    end
    refresh_properties(response)
=begin
    whitelist = properties[:whitelist].gsub(' ', '').scan(/[^,]+/)
    self.whitelist = @minecraft_server.node.update_whitelist(whitelist)
    if self.whitelist.nil?
      # TODO: error
      return false
    end
    self.ops = @minecraft_server.node.update_ops(ops)
    if self.ops.nil?
      # TODO: error
      return false
    end
    return true
=end
  end
end
