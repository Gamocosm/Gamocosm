require 'test_helper'

class ServerFlowsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  def setup
    @user = User.find(1)
    Server.first.update_columns(remote_id: nil, pending_operation: nil)
  end

  def teardown
  end

  test "a lot of things (\"test everything\" - so it goes)" do
    mock_do_base(200)
    mock_do_ssh_keys_list(200, []).times_only(1)

    login_user('test@test.com', '1234test')
    server = create_server('test2', 'vanilla_java8/1.7.10', 'nyc3', '512mb')

    mock_cf_domain(server.domain, 2)
    mock_mcsw_stop(200, server.minecraft)

    start_server(server, { motd: 'A Minecraft Server' })
    update_minecraft_properties(server, { motd: 'A Gamocosm Minecraft Server' })
    enable_autoshutdown_server(server)
    wait_for_autoshutdown_server server
    wait_for_stopping_server server

    mock_do_image_delete(200, 1).times_only(1)

    delete_server(server)
    sleep 4
    logout_user
  end

  def start_server(server, properties)
    mock_do_droplet_create
      .stub_do_droplet_create(202, server.domain, server.remote_size_slug, server.remote_region_slug, server.remote_snapshot_id || Gamocosm::DIGITAL_OCEAN_BASE_IMAGE_SLUG)
      .times_only(1)
    mock_do_droplet_actions_list(200, 1).times_only(1)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'new').times_only(1)
    mock_do_ssh_key_gamocosm(200).times_only(1)

    get start_server_path(server)
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    # this sometimes fails, leave here until fixed
    if flash[:success].nil?
      Rails.logger.error 'Start server not success'
      Rails.logger.error response.body
    end
    assert_not_nil flash[:success]
    assert_select 'meta[http-equiv=refresh]' do |elements|
      assert_equal 1, elements.count
    end
    wait_for_starting_server server
    view_server(server, properties)
  end
=begin
  def stop_server(minecraft)
    get stop_server_path(server)
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'meta[http-equiv=refresh]' do |elements|
      assert_equal 1, elements.count
    end
    wait_for_stopping_server minecraft
    get server_path(server)
    assert_response :success
    assert_select 'p', /start server to edit minecraft settings/i
  end
=end
  def create_server(name, flavour, remote_region_slug, remote_size_slug)
    old_servers_count = Server.count
    post create_servers_path, params: {
      server: {
        name: name,
        remote_region_slug: remote_region_slug,
        remote_size_slug: remote_size_slug,
        minecraft_attributes: {
          flavour: flavour,
        },
      },
    }
    assert_equal old_servers_count + 1, Server.count
    server = Server.find_by(name: name)
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    return server
  end

  def delete_server(server)
    mock_do_droplets_list(200, []).times_only(1)
    mock_do_images_list(200, []).times_only(1)
    delete server_path(server)
    assert_redirected_to servers_path
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
  end

  def view_server(server, properties, do_get = true)
    if do_get
      mock_mcsw_properties_fetch(server.minecraft).stub_mcsw_properties_fetch(200, properties).times_only(1)
      get server_path(server)
      assert_response :success
    end
    properties.each do |key, val|
      assert_select "#minecraft_properties_#{key}[value=?]", val
    end
  end

  def update_minecraft_properties(server, properties)
    mock_mcsw_properties_update(server.minecraft).stub_mcsw_properties_update(200, properties).times_only(1)
    mock_mcsw_properties_fetch(server.minecraft).stub_mcsw_properties_fetch(200, properties).times_only(1)
    put update_properties_server_path(server), params: { minecraft_properties: properties }
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    view_server(server, properties, false)
  end
=begin
  def add_friend_to_server(minecraft, friend_email)
    post add_friend_server_path(server), { minecraft_friend: { email: friend_email } }
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'td', friend_email
  end

  def remove_friend_from_server(minecraft, friend_email)
    post remove_friend_server_path(server), { minecraft_friend: { email: friend_email } }
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'td', { text: friend_email, count: 0 }
  end
=end
  def login_user(email, password)
    mock_do_droplets_list(200, []).times_only(1)
    mock_do_images_list(200, []).times_only(1)
    post user_session_path, params: { user: { email: email, password: password } }
    assert_redirected_to servers_path
    follow_redirect!
    assert_response :success
    assert_equal 'Signed in successfully.', flash[:notice]
  end

  def logout_user
    delete destroy_user_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end
=begin
  def signup_user(email, password)
    post user_registration_path, { user: { email: email, password: password, password_confirmation: password } }
    assert_redirected_to servers_path
    follow_redirect!
    assert_response :success
    assert_equal 'Welcome! You have signed up successfully.', flash[:notice]
  end
=end
  def enable_autoshutdown_server(server)
    mock_mcsw_properties_fetch(server.minecraft).stub_mcsw_properties_fetch(200, {}).times_only(1)
    get autoshutdown_enable_server_path(server)
    assert_redirected_to server_path(server)
    follow_redirect!
    assert_response :success
  end

  def track_sidekiq_worker(worker, perform_in, max_times)
    klass = worker.constantize
    if klass.jobs.size == 0
      Rails.logger.info "Tracking #{worker}: no jobs in queue (returning)."
      return
    end
    Rails.logger.info "Tracking #{worker}: started."
    sleep perform_in
    i = 0
    while i < max_times && klass.jobs.size > 0
      Rails.logger.info "Tracking #{worker}: #{klass.jobs.size} jobs, try #{i}."
      klass.perform_one
      i += 1
      sleep perform_in
    end
    assert_equal 0, klass.jobs.size, "Error tracking #{worker}: max tries exceeded"
    Rails.logger.info "Tracking #{worker}: done."
  end

  def wait_for_autoshutdown_server(server)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'shutdown').times_only(1)
    thread = nil
    mcqs = Minecraft::QueryServer.new('127.0.0.1', 25565)
    begin
      if test_have_user_server?
        sleep 32
      else
        thread = Thread.new { mcqs.run }
      end
      track_sidekiq_worker('AutoshutdownMinecraftWorker', 1, 16)
      # workers do Server.find
      server.reload
    ensure
      if !thread.nil?
        mcqs.so_it_goes = true
        thread.join
      end
    end
    assert_not server.remote.error?, "Minecraft server remote error: #{server.remote.error}"
    assert_includes ['stopping', 'saving'], server.pending_operation
  end

  def wait_for_starting_server(server)
    # MARKER: unlimited http stub
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times(2).stub_do_droplet_action_show(200, 'completed').times_only(1)

    track_sidekiq_worker('WaitForStartingServerWorker', 0, 32)
    track_sidekiq_worker('SetupServerWorker', 0, 16)

    mock_mcsw_start(server.minecraft).stub_mcsw_start(200, server.ram).times_only(1)

    track_sidekiq_worker('StartMinecraftWorker', 0, 1)
    # workers do Server.find
    server.reload

    # MARKER: unlimited http stub
    mock_mcsw_pid(server.minecraft).stub_mcsw_pid(200, 1)

    assert server.remote.exists?, 'Minecraft server remote does not exist'
    assert_not server.remote.error?, "Minecraft server remote error: #{server.remote.error}"
    assert_not server.busy?, "Minecraft server busy: #{server.minecraft.inspect}, #{server.inspect}"
    assert server.running?, "Minecraft server not running: #{server.minecraft.inspect}, #{server.inspect}"
    server.minecraft.node.invalidate
    assert server.minecraft.running?, "Minecraft not running: #{server.minecraft.inspect}, #{server.inspect}"
  end

  def wait_for_stopping_server(server)
    # MARKER: unlimited http stub
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off')
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times(2).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'snapshot').times_only(1)

    track_sidekiq_worker('WaitForStoppingServerWorker', 0, 16)

    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times(2).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_delete(200, 1).times_only(1)

    track_sidekiq_worker('WaitForSnapshottingServerWorker', 0, 32)
    # workers do Server.find
    server.reload

    assert_not server.remote.exists?, 'Minecraft server remote exists'
    assert_not server.busy?, "Minecraft server busy: #{server.minecraft.inspect}, #{server.inspect}"
  end
end
