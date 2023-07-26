require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require 'exception_notification/rails'

require_relative 'monkey_patches'

module Gamocosm
  # see ActiveSupport::TimeZone
  TIME_ZONE = 'Pacific Time (US & Canada)'
  TIME_FORMAT = '%Y %b %-d %H:%M %Z'

  MAILER = 'Gamocosm Mailer <no-reply@gamocosm.com>'
  USER_SERVERS_DOMAIN = 'users.gamocosm.com'

  SSH_PRIVATE_KEY_PATH = 'id_gamocosm'

  DIGITAL_OCEAN_BASE_IMAGE_SLUG = 'fedora-38-x64'

  MINECRAFT_FLAVOURS_GIT_URL = 'https://github.com/Gamocosm/gamocosm-minecraft-flavours.git'
  MCSW_GIT_URL = 'https://github.com/Gamocosm/minecraft-server_wrapper.git'
  MCSW_USERNAME = 'gamocosm-mothership'

  GIT_HEAD = ENV.fetch('GIT_HEAD', 'HEAD').strip
  GIT_HEAD_DATE = Time.at(ENV.fetch('GIT_HEAD_TIMESTAMP', Time.now.to_i).to_i).in_time_zone(TIME_ZONE).strftime(TIME_FORMAT)

  DIGITAL_OCEAN_API_KEY = ENV['DIGITAL_OCEAN_API_KEY']
  REDIS_HOST = ENV['REDIS_HOST']
  REDIS_PORT = ENV['REDIS_PORT']

  MINECRAFT_FLAVOURS = YAML.load_file(File.expand_path('config/minecraft_flavours.yml', Rails.root)).inject({}, &lambda do |a, x|
    x.second['versions'].each do |v|
      a["#{x.first}/#{v}"] = {
        name: "#{x.second['name']} (#{v == 'null' ? 'latest' : v})",
        time: x.second['time'],
        developers: x.second['developers'],
        website: x.second['website'],
        notes: x.second['notes'],
      }
    end
    a
  end)

  @digital_ocean = nil
  def self.digital_ocean
    if @digital_ocean.nil?
      @digital_ocean = DigitalOcean::Connection.new(DIGITAL_OCEAN_API_KEY)
    end
    @digital_ocean
  end

  def self.cloudflare
    nil
  end

  @ssh_public_key = nil
  def self.ssh_public_key
    if @ssh_public_key.nil?
      contents = `ssh-keygen -y -f "#{SSH_PRIVATE_KEY_PATH}"`
      fingerprint = Digest::MD5.hexdigest(Base64.decode64(contents.split(/\s+/m)[1])).scan(/../).join(':')
      @ssh_public_key = Struct.new(:contents, :fingerprint).new(contents, fingerprint)
    end
    @ssh_public_key
  end

  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.load_defaults '7.0'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Custom
    # it seems even if you set this, DateTime#strftime's '%Z' format still shows a numeric timezone unless you use DateTime#in_time_zone
    config.time_zone = TIME_ZONE
    config.cache_store = :redis_cache_store, {
      host: Gamocosm::REDIS_HOST,
      port: Gamocosm::REDIS_PORT,
      db: 1 + Rails.env.index,
      pool_size: 4,
      expires_in: 24.hours,
    }
    #config.exceptions_app = self.routes
    if !ENV['MAIL_SERVER_ADDRESS'].blank?
      config.action_mailer.delivery_method = :smtp
      config.action_mailer.smtp_settings = {
        address: ENV['MAIL_SERVER_ADDRESS'],
        port: ENV['MAIL_SERVER_PORT'],
        domain: ENV['MAIL_SERVER_DOMAIN'],
        user_name: ENV['MAIL_SERVER_USERNAME'],
        password: ENV['MAIL_SERVER_PASSWORD'],
        authentication: :plain,
        tls: true,
      }
    end
    config.i18n.fallbacks = [:en]
  end
end
