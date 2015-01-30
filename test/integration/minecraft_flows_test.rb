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
    assert_equal 0, Sidekiq::Worker.jobs.count, 'Unexpected Sidekiq jobs remain'
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
    user_digital_ocean_before!
    login_user('test@test.com', '1234test')
    minecraft = create_server('test', 'vanilla/1.8.1', 'nyc3', '512mb')
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
=begin
  test "mcserver" do
    user_digital_ocean_before!
    login_user('test@test.com', '1234test')
    minecraft = create_server('test', 'mc-server/null', 'nyc3', '512mb')
    start_server(minecraft, { })
    delete_server(minecraft)
    sleep 4
    logout_user
    user_digital_ocean_after!
  end

  test "forge server" do
    user_digital_ocean_before!
    login_user('test@test.com', '1234test')
    minecraft = create_server('test', 'forge/1.7.10-10.13.2.1230', 'nyc3', '512mb')
    start_server(minecraft, { motd: 'A Minecraft Server' })
    update_minecraft_properties(minecraft, { motd: 'A Gamocosm Minecraft Server' })
    delete_server(minecraft)
    sleep 4
    logout_user
    user_digital_ocean_after!
  end
=end
  test "servers page" do
    login_user('test@test.com', '1234test')
    assert_select '#new_minecraft' do
      assert_select '#minecraft_server_attributes_do_size_slug' do
        assert_select 'option[value=512mb]'
        assert_select 'option[value=1gb]'
        assert_select 'option[value=2gb]'
      end
      assert_select '#minecraft_server_attributes_do_region_slug' do
        assert_select 'option[value=nyc3]'
        assert_select 'option[value=ams3]'
        assert_select 'option[value=sfo1]'
      end
    end
    logout_user

    User.delete_all(email: 'test3@test.com')
    signup_user('test3@test.com', '3456test')
    assert_select 'form', false
    assert_select '.panel-body', /gamocosm is an open source project/i
    logout_user
  end

  def start_server(minecraft, properties)
    get start_minecraft_path(minecraft)
    assert_redirected_to minecraft_path(minecraft)
    follow_redirect!
    assert_response :success
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
    minecraft = Minecraft.first
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
    track_sidekiq_worker('SetupServerWorker', 16, 16)
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
