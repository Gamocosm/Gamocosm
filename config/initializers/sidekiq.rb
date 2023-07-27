# See
# - http://www.mikeperham.com/2015/09/24/storing-data-with-redis/
# - https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/redis_connection.rb
# - https://github.com/redis/redis-rb
# - https://github.com/sidekiq/sidekiq/wiki/Logging
redis_config = {
  host: Gamocosm::REDIS_HOST,
  port: Gamocosm::REDIS_PORT,
  db: 4 + Rails.env.index,
}
Sidekiq.configure_client do |config|
  if Rails.env.test?
    config.logger.level = :fatal
  end
  config.redis = redis_config
end
Sidekiq.configure_server do |config|
  config.redis = redis_config
end
