# See
# - http://www.mikeperham.com/2015/09/24/storing-data-with-redis/
# - https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/redis_connection.rb
# - https://github.com/redis/redis-rb
# - https://github.com/sidekiq/sidekiq/wiki/Logging
redis_config = {
  host: Gamocosm::SIDEKIQ_REDIS_HOST,
  port: Gamocosm::SIDEKIQ_REDIS_PORT,
  db: (Rails.env.production? ? 4 : (Rails.env.development? ? 1 : 2)),
}
Sidekiq.configure_client do |config|
  config.redis = redis_config
end
Sidekiq.configure_server do |config|
  config.redis = redis_config
end
