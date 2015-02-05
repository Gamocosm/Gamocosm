require 'test_helper'

class MinecraftsControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  def setup
    @owner = User.find(1)
    @friend = User.find(2)
    @other = User.find(3)
    @minecraft = Minecraft.first
    @minecraft.server.update_columns(remote_id: nil, pending_operation: nil)
    mock_http_reset!
    mock_digital_ocean_base(200, [], [], [])
    Rails.cache.clear
  end

  def teardown
    assert_equal 0, Sidekiq::Worker.jobs.total_count, "Unexpected Sidekiq jobs remain: #{Sidekiq::Worker.jobs}"
  end

  test 'servers page with digital ocean api token' do
    sign_in @owner
    get :index
    assert_response :success
    assert_select '.panel-title', 'Digital Ocean', 'No Digital Ocean panel'
    assert_select 'option[value=512mb]'
    assert_select 'option[value=1gb]'
    assert_select 'option[value=2gb]'
    assert_select 'option[value=nyc3]'
    assert_select 'option[value=ams3]'
  end

  test 'servers page without digital ocean api token' do
    sign_in @friend
    get :index
    assert_response :success
    assert_select 'h3.panel-title', { text: 'Digital Ocean', count: 0 }
    assert_select '.panel-body', /Gamocosm is an open source project to help players host cloud Minecraft servers/
  end

  test 'servers page with invalid digital ocean api token' do
    mock_digital_ocean_base(400, [], [], [])
    sign_in @owner
    get :index
    assert_response :success
    assert_select '.panel-body', /The Digital Ocean API token you entered is invalid/
    assert_select '.panel-body', /Your Digital Ocean API token is invalid/
  end

  test 'create and destroy server' do
    sign_in @owner
    begin
      post :create, {
        minecraft: {
          name: 'test2',
          flavour: 'mc-server/null',
          server_attributes: {
            do_region_slug: 'ams3',
            do_size_slug: '2gb',
          },
        },
      }
      mc2 = Minecraft.find_by(name: 'test2')
      assert_not_nil mc2, 'Unable to create Minecraft'
      assert_redirected_to minecraft_path(mc2)
      assert_not_nil flash[:success], 'No new server message'
      mc2.server.update_columns(remote_id: 1)
      mock_minecraft_running 200, mc2, 1
      delete :destroy, { id: @minecraft.id }
      assert_redirected_to minecrafts_path
      assert_equal 'Server is deleting', flash[:success], 'Minecraft delete not success'
      assert_equal 1, Minecraft.count, 'Minecraft not actually deleted'
    ensure
      Minecraft.destroy_all(name: 'test2')
    end
  end

  test 'add and remove friends from server' do
    no_friends = 'Tell your friends to sign up and add them to your server to let them start and stop it when you\'re offline.'
    sign_in @owner
    view_server @minecraft
    assert_select 'td', @friend.email
    remove_friend_from_server(@minecraft, @friend)
    assert_select 'td', no_friends
    add_friend_to_server(@minecraft, @friend)
  end

  test 'friend can start and stop server' do
    sign_in @friend
    view_server @minecraft
    mock_digital_ocean_server(200, @minecraft.server, 'new')
    mock_digital_ocean_droplet_create(200, @minecraft)
    start_server @minecraft
    @minecraft.server.update_columns(pending_operation: nil)
    mock_minecraft_running 200,  @minecraft, 1
    view_server @minecraft
    assert @minecraft.running?, 'Minecraft server isn\'t running'
    stop_server @minecraft
  end

  test 'reboot server' do
    sign_in @owner
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 1
    get :reboot, { id: @minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    view_server(@minecraft)
    assert_equal flash[:success], 'Server is rebooting'
    ensure_busy
    assert_equal 1, WaitForStartingServerWorker.jobs.count, 'No wait for starting server worker after reboot'
    WaitForStartingServerWorker.jobs.clear
    @minecraft.reload
  end

  test 'control panel download minecraft' do
    sign_in @friend
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 0
    get :download, { id: @minecraft.id }
    assert_redirected_to "http://#{Gamocosm::MCSW_USERNAME}:#{@minecraft.minecraft_wrapper_password}@#{@minecraft.server.remote.ip_address}:#{Minecraft::Node::MCSW_PORT}/download_world"
  end

  test 'update minecraft properties' do
    sign_in @owner
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 1
    put :update_properties, {
      id: @minecraft.id,
      minecraft_properties: {
        difficulty: 0,
        motd: 'A Gamocosm Minecraft Server',
      },
    }
    assert_redirected_to minecraft_path(@minecraft)
    assert_not_nil flash[:success], 'Updating minecraft properties not success'
  end

  test 'pause and resume minecraft' do
    sign_in @friend
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 1
    get :pause, { id: @minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    assert_equal 'Server paused', flash[:success], 'Minecraft pause not successful'
    mock_minecraft_running 200, @minecraft, 0
    get :resume, { id: @minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    assert_equal 'Server resumed', flash[:success], 'Minecraft resume not successful'
  end

  test 'exec minecraft command' do
    sign_in @owner
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 1
    post :command, { id: @minecraft.id, command: { data: 'help' } }
    assert_redirected_to minecraft_path(@minecraft)
    assert_equal 'Command sent', flash[:success], 'Minecraft exec command not successful'
  end

  test 'backup minecraft' do
    sign_in @friend
    @minecraft.server.update_columns(remote_id: 1)
    mock_minecraft_running 200, @minecraft, 0
    post :backup, { id: @minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    assert_equal 'World backed up remotely on server', flash[:success], 'Minecraft backup not successful'
  end

  test 'edit advanced tab' do
    sign_in @owner
    # initial values
    view_server @minecraft, { remote_setup_stage: 0, do_region_slug: 'nyc3', do_size_slug: '512mb' }
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { remote_setup_stage: 5, do_size_slug: '1gb', do_region_slug: ' nyc3 ' } } }
    assert_redirected_to minecraft_path(@minecraft)
    # updated, trimmed values
    view_server @minecraft, { remote_setup_stage: 5, do_region_slug: 'nyc3', do_size_slug: '1gb' }
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { remote_setup_stage: 0, do_size_slug: ' 512mb ', do_region_slug: 'nyc3' } } }
    assert_redirected_to minecraft_path(@minecraft)
    # reset values
    view_server @minecraft, { remote_setup_stage: 0, do_region_slug: 'nyc3', do_size_slug: '512mb' }
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { do_size_slug: ' ', do_region_slug: "\n" } } }
    assert_response :success
    # required values
    assert_not_nil flash[:error], 'Advanced tab bad form, no error message'
  end

  test 'edit ssh keys' do
    sign_in @owner
    view_server @minecraft
    assert_select '#minecraft_server_attributes_ssh_keys', 1
    assert_nil @minecraft.server.ssh_keys, 'Minecraft SSH keys were not default value'
    put :update, {
      id: @minecraft.id,
      minecraft: {
        server_attributes: {
          ssh_keys: ' 123, 456 , 789',
        },
      },
    }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_select '#minecraft_server_attributes_ssh_keys[value=?]', '123,456,789'
    put :update, {
      id: @minecraft.id,
      minecraft: {
        server_attributes: {
          ssh_keys: "\t",
        },
      },
    }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_select '#minecraft_server_attributes_ssh_keys'
    assert_nil @minecraft.server.ssh_keys, 'Minecraft SSH keys were not reset'
    put :update, {
      id: @minecraft.id,
      minecraft: {
        server_attributes: {
          ssh_keys: '123,',
        },
      },
    }
    assert_response :success
    assert_not_nil flash[:error], 'Updating ssh keys bad value, no error message'
  end

  test 'log message and clear' do
    sign_in @owner
    view_server @minecraft
    assert_select '.panel-body em', 'No messages'
    @minecraft.log_test('Hello')
    view_server @minecraft
    assert_select '.panel-body div', /Hello/
    get :clear_logs, { id: @minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_not_nil flash[:success], 'Clearing server logs not success'
    assert_select '.panel-body em', 'No messages'
  end

  test 'friend cannot delete, edit advanced tab, edit ssh keys' do
    sign_in @friend
    assert_raises(ActionController::RoutingError) do
      delete :destroy, { id: @minecraft.id }
    end
    assert_raises(ActionController::RoutingError) do
      put :update, { id: @minecraft.id, minecraft: { server_attributes: { remote_setup_stage: 5, do_size_slug: '1gb', do_region_slug: ' nyc3 ' } } }
    end
    assert_raises(ActionController::RoutingError) do
      put :update, { id: @minecraft.id, minecraft: { server_attributes: { ssh_keys: '123' } } }
    end
  end

  test 'other users see 404' do
    sign_in @other
    assert_raises(ActionController::RoutingError) do
      get :show, { id: @minecraft.id }
      assert_redirected_to new_user_session_path
    end
  end

  test 'outsiders redirected to login' do
    get :show, { id: @minecraft.id }
    assert_redirected_to new_user_session_path
  end

  def view_server(minecraft, advanced_tab = { })
    get :show, { id: @minecraft.id }
    assert_response :success
    advanced_tab.each do |k, v|
      assert_select "#minecraft_server_attributes_#{k}[value=?]", v
    end
  end

  def start_server(minecraft)
    get :start, { id: minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    view_server(minecraft)
    assert_equal flash[:success], 'Server starting'
    ensure_busy
    assert_equal 1, WaitForStartingServerWorker.jobs.count, 'No wait for starting server worker after start'
    WaitForStartingServerWorker.jobs.clear
    @minecraft.reload
  end

  def stop_server(minecraft)
    get :stop, { id: minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    view_server(minecraft)
    assert_equal flash[:success], 'Server stopping'
    ensure_busy
    assert_equal 1, WaitForStoppingServerWorker.jobs.count, 'No wait for stopping server worker after stop'
    WaitForStoppingServerWorker.jobs.clear
    @minecraft.reload
  end

  def ensure_busy
    assert_select 'meta[http-equiv=refresh]', { count: 1 }
  end

  def add_friend_to_server(minecraft, friend)
    post :add_friend, { id: minecraft.id, minecraft_friend: { email: friend.email } }
    assert_redirected_to minecraft_path(minecraft)
    view_server minecraft
    assert_not_nil flash[:success], 'Add friend to server not success'
    assert_select 'td', friend.email
  end

  def remove_friend_from_server(minecraft, friend)
    post :remove_friend, { id: minecraft.id, minecraft_friend: { email: friend.email } }
    assert_redirected_to minecraft_path(minecraft)
    view_server minecraft
    assert_not_nil flash[:success], 'Remove friend from server not success'
    assert_select 'td', { text: friend.email, count: 0 }
  end

  # TODO: these don't really belong here
  test 'delete digital ocean droplet' do
    sign_in @owner
    mock_digital_ocean_droplet_actions(200, 1)
    post :delete_digital_ocean_droplet, { digital_ocean_droplet: { remote_id: 1 } }
    assert_redirected_to minecrafts_path
    get :index
    assert_response :success
    assert_match /deleted droplet/i, flash[:notice], 'Something went wrong deleting Digital Ocean droplet from Digital Ocean control panel'
  end

  test 'delete digital ocean snapshot' do
    sign_in @owner
    mock_digital_ocean_snapshot_delete(200, 1)
    post :delete_digital_ocean_snapshot, { digital_ocean_snapshot: { remote_id: 1 } }
    assert_redirected_to minecrafts_path
    get :index
    assert_response :success
    assert_match /deleted snapshot/i, flash[:notice], 'Something went wrong deleting Digital Ocean snapshot from Digital Ocean control panel'
  end

  test 'add digital ocean ssh key' do
    sign_in @owner
    mock_digital_ocean_ssh_key_add(200, 'me', 'a b c')
    post :add_digital_ocean_ssh_key, {
      id: @minecraft.id,
      digital_ocean_ssh_key: {
        name: 'me',
        data: 'a b c',
      },
    }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_match /added ssh public key/i, flash[:success], 'Adding Digital Ocean SSH key not success'
  end

  test 'delete digital ocean ssh key' do
    sign_in @owner
    mock_digital_ocean_ssh_key_delete(204, 1)
    post :delete_digital_ocean_ssh_key, {
      id: @minecraft.id,
      digital_ocean_ssh_key: {
        remote_id: 1,
      },
    }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_match /deleted ssh public key/i, flash[:success], 'Deleting Digital Ocean SSH key not success'
  end

end
