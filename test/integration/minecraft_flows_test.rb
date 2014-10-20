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

  test "everything" do
    user_digital_ocean_before!
    login_user('test@test.com', '1234test')
    minecraft = create_server('test', 'nyc3', '512mb')
    start_server(minecraft, { motd: 'A Minecraft Server' })
    update_minecraft_properties(minecraft, { motd: 'A Gamocosm Minecraft Server' })
    add_friend_to_server(minecraft, 'test2@test.com')
    stop_server(minecraft)
    sleep 32
    logout_user
    login_user('test2@test.com', '2345test')
    start_server(minecraft, {})
    logout_user
    login_user('test@test.com', '1234test')
    view_server(minecraft, { motd: 'A Gamocosm Minecraft Server' })
    remove_friend_from_server(minecraft, 'test@test.com')
    delete_server(minecraft)
    sleep 4
    logout_user
    user_digital_ocean_after!
  end

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
      assert_equal elements.count, 1
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
      assert_equal elements.count, 1
    end
    wait_for_stopping_server minecraft
    get minecraft_path(minecraft)
    assert_response :success
    assert_select 'p', /start server to edit minecraft settings/i
  end

  def create_server(name, do_region_slug, do_size_slug)
    post minecrafts_path, { minecraft: { name: name, server_attributes: { do_region_slug: do_region_slug, do_size_slug: do_size_slug } } }
    assert_equal(Minecraft.all.count, 1)
    minecraft = Minecraft.all.first
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
    Rails.logger.info "Viewing server, Minecraft properties is #{properties}"
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
    assert_equal flash[:notice], 'Signed in successfully.'
  end

  def logout_user
    delete destroy_user_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_equal flash[:notice], 'Signed out successfully.'
  end

  def signup_user(email, password)
    post user_registration_path, { user: { email: email, password: password, password_confirmation: password } }
    assert_redirected_to minecrafts_path
    follow_redirect!
    assert_response :success
    assert_equal flash[:notice], 'Welcome! You have signed up successfully.'
  end

  def wait_for_starting_server(minecraft, times = 0)
    if times == 0
      sleep 32
    end
    Rails.logger.info "Waiting for server to start, try #{times}"
    minecraft.reload
    if times >= 32
      raise "Minecraft server did not start: #{minecraft.server.inspect}"
    end
    if !minecraft.server.remote.exists?
      raise 'Minecraft server remote does not exist'
    end
    if minecraft.server.remote.error?
      raise "Minecraft server remote error: #{minecraft.server.remote.error}"
    end
    if !minecraft.server.busy?
      assert minecraft.server.running?
      sleep 8
      minecraft.node.invalidate
      assert minecraft.running?
      sleep 16
      return
    end
    sleep 16
    wait_for_starting_server(minecraft, times + 1)
  end

  def wait_for_stopping_server(minecraft, times = 0)
    if times == 0
      sleep 32
    end
    Rails.logger.info "Waiting for server to stop, try #{times}"
    minecraft.reload
    if times >= 32
      raise "Minecraft server did not stop, #{minecraft.server.inspect}"
    end
    if minecraft.server.remote.error?
      raise "Minecraft server remote error: #{minecraft.server.remote.error}"
    end
    if !minecraft.server.busy?
      assert_not minecraft.server.remote.exists?
      return
    end
    sleep 16
    wait_for_stopping_server(minecraft, times + 1)
  end
end
