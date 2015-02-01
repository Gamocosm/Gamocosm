require 'test_helper'

class MinecraftFlowsTest < ActionDispatch::IntegrationTest
  self.use_transactional_fixtures = false
  # test "the truth" do
  #   assert true
  # end

  def setup
    @user = User.find(1)
  end

  def teardown
    assert_equal 0, Sidekiq::Worker.jobs.inject(0) { |total, kv| total + kv.second.size }, "Unexpected Sidekiq jobs remain: #{Sidekiq::Worker.jobs}"
  end

  def user_digital_ocean_before!
    @user = User.find(1)
    @user_digital_ocean_droplets_before = @user.digital_ocean_droplets.map { |x| x.id }
    @user_digital_ocean_snapshots_before = @user.digital_ocean_snapshots.map { |x| x.id }
    assert_not_nil @user_digital_ocean_droplets_before
    assert_not_nil @user_digital_ocean_snapshots_before
  end

  def user_digital_ocean_after!
    @user.invalidate
    @user_digital_ocean_droplets_after = @user.digital_ocean_droplets.map { |x| x.id }
    @user_digital_ocean_snapshots_after = @user.digital_ocean_snapshots.map { |x| x.id }
    assert_equal @user_digital_ocean_droplets_before, @user_digital_ocean_droplets_after
    assert_equal @user_digital_ocean_snapshots_before, @user_digital_ocean_snapshots_after
  end

  test "a lot of things (\"test everything\" - so it goes)" do
    if ENV['TEST_REAL'] == 'true'
      begin
        WebMock.allow_net_connect!
        do_a_lot_of_things
      ensure
        WebMock.disable_net_connect!
      end
    else
      do_a_lot_of_things
    end
  end

  def do_a_lot_of_things
    user_digital_ocean_before!
    login_user('test@test.com', '1234test')
    minecraft = create_server('test2', 'vanilla/1.8.1', 'nyc3', '512mb')
    start_server(minecraft, { motd: 'A Minecraft Server' })
    update_minecraft_properties(minecraft, { motd: 'A Gamocosm Minecraft Server' })
    enable_autoshutdown_server(minecraft)
    wait_for_autoshutdown_server minecraft
    wait_for_stopping_server minecraft
    delete_server(minecraft)
    sleep 4
    logout_user
    user_digital_ocean_after!
  end

  def start_server(minecraft, properties)
    get start_minecraft_path(minecraft)
    assert_redirected_to minecraft_path(minecraft)
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
    wait_for_starting_server minecraft
    view_server(minecraft, properties)
  end

  def stop_server(minecraft)
    get stop_minecraft_path(minecraft)
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'meta[http-equiv=refresh]' do |elements|
      assert_equal 1, elements.count
    end
    wait_for_stopping_server minecraft
    get minecraft_path(minecraft)
    assert_response :success
    assert_select 'p', /start server to edit minecraft settings/i
  end

  def create_server(name, flavour, do_region_slug, do_size_slug)
    old_minecrafts_count = Minecraft.count
    post minecrafts_path, { minecraft: { name: name, flavour: flavour, server_attributes: { do_region_slug: do_region_slug, do_size_slug: do_size_slug } } }
    assert_equal old_minecrafts_count + 1, Minecraft.count
    minecraft = Minecraft.find_by(name: name)
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    return minecraft
  end

  def delete_server(minecraft)
    delete minecraft_path(minecraft)
    assert_redirected_to minecrafts_path
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
  end

  def view_server(minecraft, properties, get = true)
    minecraft.properties.refresh
    Rails.logger.info "Viewing server, Minecraft properties is #{minecraft.properties.inspect}, expecting #{properties}"
    if get
      get minecraft_path(minecraft)
      assert_response :success
    end
    properties.each do |key, val|
      assert_select "#minecraft_properties_#{key}[value=?]", val
    end
  end

  def update_minecraft_properties(minecraft, properties)
    put update_properties_minecraft_path(minecraft), { minecraft_properties: properties }
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
    view_server(minecraft, properties, false)
  end

  def add_friend_to_server(minecraft, friend_email)
    post add_friend_minecraft_path(minecraft), { minecraft_friend: { email: friend_email } }
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'td', friend_email
  end

  def remove_friend_from_server(minecraft, friend_email)
    post remove_friend_minecraft_path(minecraft), { minecraft_friend: { email: friend_email } }
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
    assert_not_nil flash[:success]
    assert_select 'td', { text: friend_email, count: 0 }
  end

  def login_user(email, password)
    post user_session_path, { user: { email: email, password: password } }
    assert_redirected_to minecrafts_path
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

  def signup_user(email, password)
    post user_registration_path, { user: { email: email, password: password, password_confirmation: password } }
    assert_redirected_to minecrafts_path
    follow_redirect!
    assert_response :success
    assert_equal 'Welcome! You have signed up successfully.', flash[:notice]
  end

  def enable_autoshutdown_server(minecraft)
    get autoshutdown_enable_minecraft_path(minecraft)
    assert_redirected_to minecraft_path(minecraft)
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

  def wait_for_autoshutdown_server(minecraft)
    track_sidekiq_worker('AutoshutdownMinecraftWorker', 4, 16)
    # workers do Server.find, here uses minceraft.server
    minecraft.reload
    assert_not minecraft.server.remote.error?, "Minecraft server remote error: #{minecraft.server.remote.error}"
    assert_includes ['stopping', 'saving'], minecraft.server.pending_operation
  end

  def wait_for_starting_server(minecraft)
    track_sidekiq_worker('WaitForStartingServerWorker', 16, 32)
    if ENV['TEST_REAL'] == 'true' || ENV['TEST_DOCKER'] == 'true'
      track_sidekiq_worker('SetupServerWorker', 16, 16)
    else
      if SetupServerWorker.jobs.count > 0
        assert_equal 1, SetupServerWorker.jobs.count, "More than 1 SetupServerWorker jobs: #{SetupServerWorker.jobs}"
        SetupServerWorker.jobs.clear
        StartMinecraftWorker.perform_in(0.seconds, minecraft.server.id)
      end
    end
    track_sidekiq_worker('StartMinecraftWorker', 4, 1)
    # workers do Server.find, here uses minceraft.server
    minecraft.reload
    assert minecraft.server.remote.exists?, 'Minecraft server remote does not exist'
    assert_not minecraft.server.remote.error?, "Minecraft server remote error: #{minecraft.server.remote.error}"
    assert_not minecraft.server.busy?, "Minecraft server busy: #{minecraft.inspect}, #{minecraft.server.inspect}"
    assert minecraft.server.running?, "Minecraft server not running: #{minecraft.inspect}, #{minecraft.server.inspect}"
    minecraft.node.invalidate
    assert minecraft.running?, "Minecraft not running: #{minecraft.inspect}, #{minecraft.server.inspect}"
    # give server time to generate files
    sleep 16
  end

  def wait_for_stopping_server(minecraft)
    track_sidekiq_worker('WaitForStoppingServerWorker', 16, 16)
    track_sidekiq_worker('WaitForSnapshottingServerWorker', 16, 32)
    # workers do Server.find, here uses minceraft.server
    minecraft.reload
    assert_not minecraft.server.remote.exists?, 'Minecraft server remote exists'
    assert_not minecraft.server.busy?, "Minecraft server busy: #{minecraft.inspect}, #{minecraft.server.inspect}"
  end
end
