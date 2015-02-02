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

Sidekiq::Worker.jobs.define_singleton_method(:total_count, lambda { self.inject(0) { |total, kv| total + kv.second.size } })

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def have_user_server_for_test?
    return ENV['TEST_REAL'] == 'true' || ENV['TEST_DOCKER'] == 'true'
  end

  # WebMock base helpers
  def mock_http_reset!
    WebMock.reset!
  end

  def mock_http_return_json(stub, status, res)
    return stub.to_return(status: status, body: res.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  def mock_http_json(verb, path, status, res, req)
    stub = stub_request(verb, path)
    if !req.nil?
      stub.with(body: hash_including(req))
    end
    return mock_http_return_json(stub, status, res)
  end

  def mock_digital_ocean(verb, path, status, res, req)
    return mock_http_json(verb, /#{File.join(Barge::Client::DIGITAL_OCEAN_URL, path)}/, status, res, req)
  end

  def mock_cloudflare(verb, a, status, res, req)
    stub = stub_request(verb, CloudFlare::Client::CLOUDFLARE_API_URL)
    stub.with(query: {
      a: a,
      tkn: Gamocosm.cloudflare_api_token,
      email: Gamocosm.cloudflare_email,
      z: Gamocosm.user_servers_domain,
    }.merge(req))
    mock_http_return_json(stub, status, res)
  end

  def mock_minecraft_node(verb, minecraft, endpoint, status, res, req)
    mock_http_json(
      verb,
      minecraft.node.full_url(endpoint).sub('http://', "http://#{Gamocosm.minecraft_wrapper_username}:#{minecraft.minecraft_wrapper_password}@"),
      status,
      res,
      req,
    )
  end

  # WebMock abstraction helpers
  def mock_digital_ocean_base(status, droplets, images, ssh_keys)
    mock_digital_ocean(:get, '/droplets', status, { droplets: droplets }, nil)
    mock_digital_ocean(:get, '/images', status, { images: images }, nil)
    mock_digital_ocean(:get, '/account/keys', status, { ssh_keys: ssh_keys }, nil)
    mock_digital_ocean(:get, '/sizes', status, { sizes: DigitalOcean::Size::DEFAULT_SIZES }, nil)
    mock_digital_ocean(:get, '/regions', status, { sizes: DigitalOcean::Region::DEFAULT_REGIONS }, nil)
    mock_digital_ocean(:post, '/account/keys', status, { ssh_key: { id: 1 } }, {
      name: 'gamocosm',
      public_key: Gamocosm.digital_ocean_public_key,
    })
  end

  def mock_digital_ocean_droplet_actions(status, remote_id)
    mock_digital_ocean(:get, "/droplets/#{remote_id}/actions", status, {
      actions: [{ id: 1 }],
    }, nil)
    mock_digital_ocean(:post, "/droplets/#{remote_id}/actions", status, {
      action: { id: 1 }
    }, {
      type: /shutdown|reboot|snapshot/,
    })
    mock_digital_ocean(:delete, "/droplets/#{remote_id}", status, { }, nil)
  end

  def mock_digital_ocean_action(status, droplet_id, action_id, remote_status)
    mock_digital_ocean(:get, "/droplets/#{droplet_id}/actions/#{action_id}", status, {
      action: {
        status: remote_status,
      },
    }, nil)
  end

  def mock_digital_ocean_action_after(stub, status, remote_status)
    mock_http_return_json(stub, status, {
      action: {
        status: remote_status,
      },
    })
  end

  def mock_digital_ocean_snapshot_delete(status, remote_id)
    mock_digital_ocean(:delete, "/images/#{remote_id}", status, { }, nil)
  end

  def mock_digital_ocean_ssh_key_add(status, name, public_key)
    mock_digital_ocean(:post, '/account/keys', status, {
      ssh_key: {
        id: 1,
      },
    }, {
      name: name,
      public_key: public_key,
    })
  end

  def mock_digital_ocean_ssh_key_delete(status, key_id)
    mock_digital_ocean(:delete, "/account/keys/#{key_id}", status, { }, nil)
  end

  def mock_digital_ocean_ssh_key_get(status, key_id, public_key)
    mock_digital_ocean(:get, "/account/keys/#{key_id}", status, {
      ssh_key: {
        public_key: public_key,
      },
    }, nil)
  end

  def mock_digital_ocean_server(status, server, remote_status)
    mock_digital_ocean(:get, "/droplets/#{server.remote_id}", status, {
      droplet: {
        id: 1,
        networks: { v4: [{ ip_address: 'localhost', type: 'public' }] },
        status: remote_status,
        snapshot_ids: [1],
      },
    }, nil)
    if !server.remote_id.nil?
      mock_digital_ocean_droplet_actions(status, server.remote_id)
    end
  end

  def mock_digital_ocean_droplet_create(status, minecraft)
    mock_digital_ocean(:post, '/droplets', status, { droplet: { id: 1 } }, {
      name: "#{minecraft.name}.minecraft.gamocosm",
      size: minecraft.server.do_size_slug,
      region: minecraft.server.do_region_slug,
      image: Gamocosm.digital_ocean_base_image_slug,
      ssh_keys: ['1'],
    })
    mock_digital_ocean_droplet_actions(status, 1)
  end

  def mock_cloudflare_list_dns(status, recs)
    mock_cloudflare(:post, 'rec_load_all', status, {
      result: 'success',
      response: {
        recs: {
          objs: recs,
        },
      },
    }, { })
  end

  def mock_cloudflare_add_dns(status, name, content)
    mock_cloudflare(:post, 'rec_new', status, {
      result: 'success',
    }, {
      type: 'A',
      ttl: 120,
      name: name,
      content: content,
    })
  end

  def mock_cloudflare_edit_dns(status, id, name, content)
    mock_cloudflare(:post, 'rec_edit', status, {
      result: 'success',
    }, {
      type: 'A',
      ttl: 120,
      id: id,
      name: name,
      content: content,
    })
  end

  def mock_cloudflare_delete_dns(status, id)
    mock_cloudflare(:post, 'rec_delete', status, {
      result: 'success',
    }, {
      id: id,
    })
  end

  # WebMock convenience helpers
  def mock_minecraft_running(status, minecraft, pid)
    mock_digital_ocean_server(200, minecraft.server, 'active')
    assert minecraft.server.running?, 'Minecraft server isn\'t running'
    mock_minecraft_node(:get, minecraft, :pid, status, {
      pid: pid,
    }, nil)
    mock_minecraft_properties(status, minecraft, { })
    mock_minecraft_node(:get, minecraft, :stop, status, { }, nil)
    mock_minecraft_node(:post, minecraft, :backup, status, { }, nil)
    mock_minecraft_node(:post, minecraft, :start, status, {
      pid: 1,
    }, {
      ram: "#{minecraft.server.ram}M",
    })
    mock_minecraft_node(:post, minecraft, :exec, status, { }, {
      command: 'help',
    })
  end

  def mock_minecraft_properties(status, minecraft, updated_properties)
    p = Minecraft::Properties::DEFAULT_PROPERTIES.merge(updated_properties)
    mock_minecraft_node(:get, minecraft, :minecraft_properties, status, {
      properties: p,
    }, nil)
    mock_minecraft_node(:post, minecraft, :minecraft_properties, status, {
      properties: p,
    }, nil)
  end
end
