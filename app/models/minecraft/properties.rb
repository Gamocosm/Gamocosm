class Minecraft::Properties
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

  def initialize(minecraft)
    @minecraft = minecraft
    response = @minecraft.node.properties
    if response.error?
      @error = response
      error!
      return
    end
    refresh_properties(response)
  end

  def error
    return @error
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
    response = @minecraft.node.update_properties(properties)
    if response.error?
      return response
    end
    refresh_properties(response)
    return nil
  end
end
