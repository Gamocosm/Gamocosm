require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gamocosm
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Custom
    config.cache_store = :dalli_store, ENV['MEMCACHED_HOST'] || 'localhost', { namespace: "gamocosm-#{Rails.env}", expires_in: 24.hours, compress: true }
    config.exceptions_app = self.routes
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
  end

  def self.minecraft_flavours_git_url
    'https://github.com/Gamocosm/gamocosm-minecraft-flavours.git'
  end

  def self.minecraft_server_wrapper_git_url
    'https://github.com/Gamocosm/minecraft-server_wrapper.git'
  end

  def self.minecraft_wrapper_username
    'gamocosm-mothership'
  end

  def self.digital_ocean_base_image_slug
    'fedora-20-x64'
  end

  def self.minecraft_flavours
    return {
      'vanilla/1.8.1' => { name: 'Vanilla (latest)', time: 1 },
      'mc-server/null' => { name: 'MCServer', time: 1 },
      'forge/1.7.10-10.13.2.1230' => { name: 'Forge (1.7.10)', time: 1 },
      'spigot/1.8' => { name: 'Spigot (1.8)', time: 10 },
      'craftbukkit/1.8' => { name: 'CraftBukkit (1.8)', time: 10 },
      'agrarianskies/1.6.4' => { name: 'Agrarian Skies (1.6.4) 2GB+ Recommended', time: 1 },
	  'ftbresurrection/1.7.10' => { name: 'FTB Resurrection (1.7.10) 2GB+ Recommended', time: 2 },
	  'crashlanding/1.6.4' => { name: 'Crash Landing (1.6.4) 2GB+ Recommended', time: 1 },
	  'direwolf20/1.7.10' => { name: 'Direwolf20 (1.7.10) 2GB+ Recommended', time: 2 },
    }
  end

  def self.digital_ocean_public_key
    public_key = File.read(Gamocosm.digital_ocean_ssh_public_key_path)
    return public_key
  end

  def self.digital_ocean_public_key_fingerprint
    public_key = self.digital_ocean_public_key
    fingerprint = Digest::MD5.hexdigest(Base64.decode64(public_key.split(/\s+/m)[1])).scan(/../).join(':')
  end

  def self.digital_ocean_api_key
    ENV['DIGITAL_OCEAN_API_KEY']
  end

  def self.digital_ocean_ssh_public_key_path
    ENV['DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH']
  end

  def self.digital_ocean_ssh_private_key_path
    ENV['DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH']
  end

  def self.digital_ocean_ssh_private_key_passphrase
    ENV['DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE']
  end

  def self.sidekiq_admin_username
    ENV['SIDEKIQ_ADMIN_USERNAME']
  end

  def self.sidekiq_admin_password
    ENV['SIDEKIQ_ADMIN_PASSWORD']
  end

  def self.user_servers_domain
    ENV['USER_SERVERS_DOMAIN']
  end

  def self.cloudflare_api_token
    ENV['CLOUDFLARE_API_TOKEN']
  end

  def self.cloudflare_email
    ENV['CLOUDFLARE_EMAIL']
  end
end
