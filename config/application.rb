require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gamocosm
  DIGITAL_OCEAN_API_KEY = ENV['DIGITAL_OCEAN_API_KEY']
  DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH = ENV['DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH']
  DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH = ENV['DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH']
  DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE = ENV['DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE']
  SIDEKIQ_ADMIN_USERNAME = ENV['SIDEKIQ_ADMIN_USERNAME']
  SIDEKIQ_ADMIN_PASSWORD = ENV['SIDEKIQ_ADMIN_PASSWORD']
  USER_SERVERS_DOMAIN = ENV['USER_SERVERS_DOMAIN']
  CLOUDFLARE_API_TOKEN = ENV['CLOUDFLARE_API_TOKEN']
  CLOUDFLARE_EMAIL = ENV['CLOUDFLARE_EMAIL']
  CLOUDFLARE_ZONE = ENV['CLOUDFLARE_ZONE']
  MINECRAFT_FLAVOURS_GIT_URL = ENV['MINECRAFT_FLAVOURS_GIT_URL']

  MINECRAFT_FLAVOURS = YAML.load_file(File.expand_path('config/minecraft_flavours.yml', Rails.root)).inject({}, &lambda do |a, x|
    x.second['versions'].each do |v|
      a["#{x.first}/#{v['tag']}"] = {
        name: v['name'],
        time: x.second['time'],
        developers: x.second['developers'],
        website: x.second['website'],
        notes: x.second['notes'],
      }
    end
    a
  end)
  MCSW_GIT_URL = 'https://github.com/Gamocosm/minecraft-server_wrapper.git'
  MCSW_USERNAME = 'gamocosm-mothership'
  DIGITAL_OCEAN_BASE_IMAGE_SLUG = 'fedora-32-x64'
  DIGITAL_OCEAN_SSH_PUBLIC_KEY = File.read(DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH)
  DIGITAL_OCEAN_SSH_PUBLIC_KEY_FINGERPRINT = Digest::MD5.hexdigest(Base64.decode64(DIGITAL_OCEAN_SSH_PUBLIC_KEY.split(/\s+/m)[1])).scan(/../).join(':')
  GIT_HEAD = `git rev-parse HEAD`.strip
  GIT_HEAD_DATE = Time.at(`git show -s --format=%ct HEAD`.to_i).strftime('%Y %b %-d %H:%M %Z')
  # see ActiveSupport::TimeZone
  TIMEZONE = 'Pacific Time (US & Canada)'

  @digital_ocean = nil
  def self.digital_ocean
    if @digital_ocean.nil?
      @digital_ocean = DigitalOcean::Connection.new(DIGITAL_OCEAN_API_KEY)
    end
    return @digital_ocean
  end

  @cloudflare = nil
  def self.cloudflare
    if @cloudflare.nil?
      @cloudflare = CloudFlare::Client.new(CLOUDFLARE_EMAIL, CLOUDFLARE_API_TOKEN, USER_SERVERS_DOMAIN, CLOUDFLARE_ZONE)
    end
    return @cloudflare
  end

  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    config.load_defaults '6.0'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Custom
    # it seems even if you set this, DateTime#strftime's '%Z' format still shows a numeric timezone unless you use DateTime#in_time_zone
    config.time_zone = TIMEZONE
    config.cache_store = :mem_cache_store, 'localhost', { namespace: "gamocosm-#{Rails.env}", expires_in: 24.hours, compress: true }
    #config.exceptions_app = self.routes
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV['MAIL_SERVER_ADDRESS'],
      port: ENV['MAIL_SERVER_PORT'],
      domain: ENV['MAIL_SERVER_DOMAIN'],
      user_name: ENV['MAIL_SERVER_USERNAME'],
      password: ENV['MAIL_SERVER_PASSWORD'],
      authentication: 'plain',
      enable_starttls_auto: true
    }
    config.i18n.fallbacks = [ :en ]
  end
end
