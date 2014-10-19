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

  def self.minecraft_jar_default_url
    'https://s3.amazonaws.com/Minecraft.Download/versions/1.8/minecraft_server.1.8.jar'
  end

  def self.minecraft_wrapper_username
    'gamocosm-mothership'
  end

  def self.digital_ocean_base_image_id
    'fedora-20-x64'
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
end
