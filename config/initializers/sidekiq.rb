Sidekiq.configure_client do |config|
  # see
  # - http://www.mikeperham.com/2015/09/24/storing-data-with-redis/
  # - https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/redis_connection.rb
  # - https://github.com/redis/redis-rb
  config.redis = { 
    db: (
      Rails.env.production? ? 4 : 
      ((Rails.env.development? || Rails.env.docker?)? 1 : 2)),
    url: (Rails.env.docker? ? 'redis://redis:6379/1' : '')}
end

Sidekiq.configure_server do |config|
  config.redis = { 
    db: (
      Rails.env.production? ? 4 : 
      ((Rails.env.development? || Rails.env.docker?)? 1 : 2)),
    url: (Rails.env.docker? ? 'redis://redis:6379/1' : '')}
end
