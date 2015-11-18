Sidekiq.configure_client do |config|
  # see
  # - http://www.mikeperham.com/2015/09/24/storing-data-with-redis/
  # - https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/redis_connection.rb
  # - https://github.com/redis/redis-rb
  config.redis = { db: (Rails.env.production? ? 0 : (Rails.env.development? ? 1 : 2)) }
end
Sidekiq.configure_server do |config|
  config.redis = { db: (Rails.env.production? ? 0 : (Rails.env.development? ? 1 : 2)) }
end
