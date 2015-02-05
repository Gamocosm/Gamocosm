Sidekiq.configure_client do |config|
  config.redis = { namespace: "gamocosm-#{Rails.env}" }
end
Sidekiq.configure_server do |config|
  config.redis = { namespace: "gamocosm-#{Rails.env}" }
end
