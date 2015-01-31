ENV['RAILS_ENV'] ||= 'test'
require 'simplecov'
require 'coveralls'
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter,
]
SimpleCov.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require File.expand_path('test/fixtures/seeds.rb', Rails.root)
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require 'webmock/minitest'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def mock_http_json(verb, path, res, req, status)
    stub = stub_request(verb, path)
    if !req.nil?
      stub.with(body: hash_including(req))
    end
    stub.to_return(status: status, body: res.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def mock_digital_ocean(verb, path, res, req = nil, status = 200)
    mock_http_json(verb, /#{File.join(Barge::Client::DIGITAL_OCEAN_URL, path)}/, res, req, status)
  end

  def mock_cloudflare(verb, path, res, req = nil)
    mock_http_json(verb, File.join(CloudFlare::Client::CLOUDFLARE_API_URL, path), res, req, 200)
  end

  def mock_minecraft_node(verb, minecraft, endpoint, res, req = nil)
    mock_http_json(
      verb,
      minecraft.node.full_url(endpoint).sub('http://', "http://#{Gamocosm.minecraft_wrapper_username}:#{@minecraft.minecraft_wrapper_password}@"),
      res,
      req,
      200,
    )
  end

  def mock_http_reset!
    WebMock.reset!
  end
end
