ENV['RAILS_ENV'] ||= 'test'
require 'simplecov'
SimpleCov.start
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require File.expand_path('test/fixtures/seeds.rb', Rails.root)
require 'sidekiq/testing'
#Sidekiq::Testing.fake!
require 'webmock/minitest'

#Sidekiq::Logging.logger = Rails.logger
Sidekiq.logger.level = Logger::WARN

def test_have_user_server?
  ENV['TEST_DOCKER'] == 'true'
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...
  self.use_transactional_tests = false

  setup do
    Rails.cache.clear
    WebMock.reset!
  end

  teardown do
    q = Sidekiq::Queue.new
    assert_equal 0, q.size, "Unexpected Sidekiq jobs remain: #{q.size}"
  end

  def with_minecraft_query_server(&block)
    mcqs = Minecraft::QueryServer.new('127.0.0.1', 25565)
    thread = Thread.new { mcqs.run }
    begin
      block.call(mcqs)
    ensure
      mcqs.so_it_goes = true
      thread.join
    end
  end

  # hmmm
  def patch_schedule_time
    class << ScheduledTask::Partition
      def server_current
        ScheduledTask::Partition.new(0)
      end
    end
  end

  # WebMock basic helpers
  def mock_digital_ocean(verb, path)
    stub = stub_request(verb, File.join(DigitalOcean::Connection::API_URL, path))
=begin
    if verb == :get
      stub.with({
        query: hash_including({ per_page: DigitalOcean::Connection::PER_PAGE.to_s }),
      })
    end
=end
    stub
  end

  def mock_mcsw(verb, minecraft, endpoint)
    stub_request(verb, "http://127.0.0.1:#{Minecraft::Node::MCSW_PORT}/#{endpoint}").with(basic_auth: [ Gamocosm::MCSW_USERNAME, minecraft.mcsw_password ])
  end

  # WebMock helpers that include response
  def mock_do_base(status)
    # ensure file loaded
    DigitalOcean::Connection
    mock_digital_ocean(:get, '/sizes')
      .stub_do_list
      .to_return_json(status, { sizes: DigitalOcean::Size::DEFAULT_SIZES })
    mock_digital_ocean(:get, '/regions')
      .stub_do_list
      .to_return_json(status, { regions: DigitalOcean::Region::DEFAULT_REGIONS })
  end

  def mock_do_droplet_actions_list(status, droplet_id)
    mock_digital_ocean(:get, "/droplets/#{droplet_id}/actions")
      .to_return_json(status, { actions: [{ id: 1 }], meta: { total: 1 } })
      .with(query: {
        page: 1,
        per_page: 20,
      })
  end

  def mock_do_droplet_delete(status, droplet_id)
    mock_digital_ocean(:delete, "/droplets/#{droplet_id}").to_return_json(status, {})
  end

  def mock_do_image_delete(status, image_id, data = {})
    mock_digital_ocean(:delete, "/images/#{image_id}").to_return_json(status, data)
  end

  def mock_do_ssh_key_delete(status, key_id)
    mock_digital_ocean(:delete, "/account/keys/#{key_id}").to_return_json(status, {})
  end

  def mock_do_ssh_key_gamocosm(status)
    mock_do_ssh_key_add().stub_do_ssh_key_add(status, 'gamocosm', Gamocosm.ssh_public_key.contents)
  end

  def mock_do_droplets_list(status, droplets)
    mock_digital_ocean(:get, '/droplets')
      .to_return_json(status, { droplets: droplets, meta: { total: droplets.length } })
      .stub_do_list
  end

  def mock_do_images_list(status, images)
    mock_digital_ocean(:get, '/images')
      .to_return_json(status, { images: images, meta: { total: images.length } })
      .stub_do_list
  end

  def mock_do_ssh_keys_list(status, ssh_keys)
    mock_digital_ocean(:get, '/account/keys')
      .to_return_json(status, { ssh_keys: ssh_keys, meta: { total: ssh_keys.length } })
      .stub_do_list
  end

  def mock_mcsw_stop(status, mc)
    mock_mcsw(:post, mc, :stop).to_return_json(status, {})
  end

  def mock_mcsw_backup(status, mc)
    mock_mcsw(:post, mc, :backup).to_return_json(status, {})
  end

  # WebMock helpers just urls
  def mock_do_droplet_action(droplet_id)
    mock_digital_ocean(:post, "/droplets/#{droplet_id}/actions")
  end

  def mock_do_droplet_action_show(droplet_id, action_id)
    mock_digital_ocean(:get, "/droplets/#{droplet_id}/actions/#{action_id}")
  end

  def mock_do_ssh_key_add()
    mock_digital_ocean(:post, '/account/keys')
  end

  def mock_do_ssh_key_show(key_id)
    mock_digital_ocean(:get, "/account/keys/#{key_id}")
  end

  def mock_do_droplet_show(remote_id)
    mock_digital_ocean(:get, "/droplets/#{remote_id}")
  end

  def mock_do_droplet_create()
    mock_digital_ocean(:post, '/droplets')
  end

  def mock_mcsw_start(mc)
    mock_mcsw(:post, mc, :start)
  end

  def mock_mcsw_pid(mc)
    mock_mcsw(:get, mc, :pid)
  end

  def mock_mcsw_exec(mc)
    mock_mcsw(:post, mc, :exec)
  end

  def mock_mcsw_properties_fetch(mc)
    mock_mcsw(:get, mc, :minecraft_properties)
  end

  def mock_mcsw_properties_update(mc)
    mock_mcsw(:post, mc, :minecraft_properties)
  end
end

class WebMock::RequestStub
  def to_return_json(status, res)
    self.to_return({ status: status, body: res.to_json, headers: { 'Content-Type' => 'application/json' } })
  end

  def with_body_hash_including(req)
    self.with(body: WebMock::API.hash_including(req))
  end

  def times_only(n)
    self.times(n).to_raise(RuntimeError)
  end

  def stub_do_list
    self.with({ query: WebMock::API.hash_including({
      page: '1',
      per_page: '20',
    }) })
  end

  def stub_do_droplet_action(status, action)
    self.with_body_hash_including({
      type: action,
    }).to_return_json(status, { action: { id: 1 } })
  end

  def stub_do_droplet_action_show(status, remote_status)
    self.to_return_json(status, {
      action: {
        status: remote_status
      }
    })
  end

  def stub_do_droplet_show(status, remote_status, opts = {})
    self.to_return_json(status, {
      droplet: {
        id: 1,
        networks: { v4: [{ ip_address: '127.0.0.1', type: 'public' }] },
        status: remote_status,
        snapshot_ids: [1],
      }.merge(opts),
    })
  end

  def stub_do_droplet_create(status, name, size, region, image)
    self.with_body_hash_including({
      name: "#{name}.#{Gamocosm::USER_SERVERS_DOMAIN}",
      size: size,
      region: region,
      image: image,
      ssh_keys: [ 1 ],
    }).stub_do_droplet_show(status, 'new')
  end

  def stub_do_ssh_key_show(status, name, public_key)
    self.to_return_json(status, {
      ssh_key: {
        id: 1,
        name: name,
        public_key: public_key,
      },
    })
  end

  def stub_do_ssh_key_add(status, name, public_key)
    self.with_body_hash_including({
      name: name,
      public_key: public_key,
    }).stub_do_ssh_key_show(status, name, public_key)
  end

  def stub_cf_response(status, success, result)
    self.to_return_json(status, {
      success: success,
      result: result,
    })
  end

  def stub_mcsw_pid(status, pid, opts = {})
    self.to_return_json(status, { pid: pid }.merge(opts))
  end

  def stub_mcsw_start(status, ram)
    self.with_body_hash_including({
      ram: "#{ram}M",
    }).stub_mcsw_pid(status, 1)
  end

  def stub_mcsw_exec(status, command)
    self.with_body_hash_including({
      command: command,
    }).to_return_json(status, {})
  end

  def stub_mcsw_properties_fetch(status, properties)
    self.to_return_json(status, {
      properties: Minecraft::Properties::DEFAULT_PROPERTIES.merge(properties),
    })
  end

  def stub_mcsw_properties_update(status, properties)
    self.with_body_hash_including({ properties: properties }).stub_mcsw_properties_fetch(status, properties)
  end
end

if !test_have_user_server?
  # reference SetupServerWorker so it loads before we patch it
  SetupServerWorker
  class SetupServerWorker
    def on(hosts, options = {}, &block)
      Rails.logger.info "SSHKit mocking on: #{hosts}..."
      block.call
      Rails.logger.info "SSHKit mocking on: #{hosts}, done."
    end

    def test(command, args = [])
      Rails.logger.info "SSHKit mocking test: #{command} #{args.join(' ')}"
      true
    end

    def within(directory, &block)
      Rails.logger.info "SSHKit mocking within: #{directory}..."
      block.call
      Rails.logger.info "SSHKit mocking within: #{directory}, done."
    end

    def execute(*args)
      Rails.logger.info "SSHKit mocking command: #{args.join(' ')}"
    end

    def with(environment, &block)
      Rails.logger.info "SSHKit mocking with: #{environment}..."
      block.call
      Rails.logger.info "SSHKit mocking with: #{environment}, done."
    end
  end
end
