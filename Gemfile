source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails'
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'
# Use postgresql as the database for Active Record
gem 'pg'
# Use SCSS for stylesheets
gem 'sassc-rails'
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
#gem 'jbuilder'

# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
#gem 'spring',        group: :development

# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use debugger
# gem 'debugger', group: [:development, :test]

# Custom
gem 'puma'
gem 'sidekiq'

gem 'exception_notification'

gem 'redis'
gem 'hiredis'
gem 'connection_pool'

gem 'devise'
gem 'faraday'
gem 'faraday_middleware'
gem 'simple_form'
gem 'droplet_kit', git: 'https://github.com/Gamocosm/droplet_kit'

gem 'sshkit'
# https://github.com/net-ssh/net-ssh
gem 'bcrypt_pbkdf'
gem 'x25519'
gem 'ed25519'

# Gamocosm user servers domain DNS.
gem 'rubydns'

# CSS styles; pin to exact version. Used with rails sprockets.
gem 'bootstrap-sass', '~> 3.4.1'
gem 'font-awesome-sass', '~> 6.4.0'

group :development do
  # https://guides.rubyonrails.org/configuring.html#config-file-watcher
  gem 'listen'

  gem 'annotate', require: false
end
group :test do
  gem 'simplecov'
  gem 'webmock'
end
