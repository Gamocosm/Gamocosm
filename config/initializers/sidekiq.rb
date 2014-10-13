Sidekiq.configure_client do |config|
  config.redis = { :url => ENV['SIDEKIQ_REDIS_URL'] || 'redis://localhost:6379/12', namespace: "gamocosm-#{Rails.env}" }
end
Sidekiq.configure_server do |config|
  config.redis = { :url => ENV['SIDEKIQ_REDIS_URL'] || 'redis://localhost:6379/12', namespace: "gamocosm-#{Rails.env}" }
end
