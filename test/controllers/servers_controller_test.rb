require 'test_helper'

class ServersControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  def setup
    @owner = User.find(1)
    @friend = User.find(2)
    @other = User.find(3)
    @server= Server.first
    @server.logs.delete_all
    @server.update_columns(remote_id: nil, pending_operation: nil, setup_stage: 0)
  end

  def teardown
  end

  test 'servers page with digital ocean api token' do
    mock_do_base(200)
    mock_do_droplets_list(200, [])
    mock_do_images_list(200, [])
    sign_in @owner
    get :index
    assert_response :success
    assert_select '.panel-title', 'Digital Ocean', 'No Digital Ocean panel'
  end

  test 'servers create page' do
    mock_do_base(200)
    sign_in @owner
    get :new
    assert_response :success
    assert_select 'option[value="512mb"]'
    assert_select 'option[value="1gb"]'
    assert_select 'option[value="2gb"]'
    assert_select 'option[value="nyc3"]'
    assert_select 'option[value="ams3"]'
  end

  test 'servers page without digital ocean api token' do
    sign_in @friend
    get :index
    assert_response :success
    assert_select 'h3.panel-title', { text: 'Digital Ocean', count: 0 }
    # TODO: how did this ever pass? where did it come from?
    #assert_select '.panel-body', /Gamocosm is an open source project to help players host cloud Minecraft servers/
  end

  test 'create and destroy server' do
    mock_do_droplet_delete(200, 1)
    sign_in @owner
    begin
      old_server_count = Server.count
      post :create, params: {
        server: {
          name: 'test2',
          remote_region_slug: 'ams3',
          remote_size_slug: '2gb',
          minecraft_attributes: {
            flavour: 'cuberite/null',
          },
        },
      }
      s2 = Server.find_by(name: 'test2')
      assert_not_nil s2, 'Unable to create server'
      assert_redirected_to server_path(s2)
      assert_not_nil flash[:success], 'No new server message'
      s2.update_columns(remote_id: 1)
      mock_cf_dns_list(200, true, [], s2.domain)
      delete :destroy, params: { id: s2.id }
      assert_redirected_to servers_path
      assert_equal 'Server is deleting', flash[:success], 'Server delete not success'
      assert_equal old_server_count, Server.count, 'Server not actually deleted'
    ensure
      Server.where(name: 'test2').destroy_all
    end
  end

  test 'create server bad input' do
    mock_do_base(200)
    sign_in @owner
    begin
      post :create, params: {
        server: {
          name: 'test2',
          remote_region_slug: 'ams3',
          remote_size_slug: '2gb',
          minecraft_attributes: {
            flavour: 'badness',
          },
        },
      }
      assert_response :success
      assert_equal 'Something went wrong. Please try again', flash[:error], 'Should have failed creating server with bad input'
      assert_select 'span.help-block', 'Invalid flavour'
    ensure
      Server.where(name: 'test2').destroy_all
    end
  end

  test 'add and remove friends from server' do
    no_friends = 'Tell your friends to sign up and add them to your server to let them start and stop it when you\'re offline.'
    sign_in @owner
    view_server @server
    assert_select '.friend .email', @friend.email
    remove_friend_from_server(@server, @friend)
    assert_select 'p', no_friends
    add_friend_to_server(@server, @friend)
  end

  test 'friend can start and stop server' do
    @server.update_columns(remote_snapshot_id: nil)
    mock_do_ssh_keys_list(200, []).times_only(1)
    mock_do_ssh_key_gamocosm(200)
    mock_do_droplet_create().stub_do_droplet_create(202, @server.name, @server.remote_size_slug, @server.remote_region_slug, Gamocosm::DIGITAL_OCEAN_BASE_IMAGE_SLUG)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'new').times(1).stub_do_droplet_show(200, 'active')
    mock_do_droplet_actions_list(200, 1)
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1)
    mock_mcsw_stop(200, @server.minecraft)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'shutdown')
    sign_in @friend
    view_server @server
    start_server @server
    @server.update_columns(pending_operation: nil)
    view_server @server
    assert @server.minecraft.running?, 'Minecraft server isn\'t running'
    stop_server @server
  end

  test 'reboot server' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'reboot')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1)
    sign_in @owner
    @server.update_columns(remote_id: 1)
    get :reboot, params: { id: @server.id }
    assert_redirected_to server_path(@server)
    view_server(@server)
    assert_equal flash[:success], 'Server is rebooting'
    ensure_busy
    assert_equal 1, WaitForStartingServerWorker.jobs.count, 'No wait for starting server worker after reboot'
    WaitForStartingServerWorker.jobs.clear
    @server.reload
  end

  test 'control panel download minecraft' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 0)
    sign_in @friend
    @server.update_columns(remote_id: 1)
    get :download, params: { id: @server.id }
    assert_redirected_to "http://#{Gamocosm::MCSW_USERNAME}:#{@server.minecraft.mcsw_password}@#{@server.remote.ip_address}:#{Minecraft::Node::MCSW_PORT}/download_world"
  end

  test 'update minecraft properties' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 0)
    p = {
      difficulty: '0',
      motd: 'A Gamocosm Minecraft Server',
    }
    mock_mcsw_properties_update(@server.minecraft).stub_mcsw_properties_update(200, p)
    mock_mcsw_properties_fetch(@server.minecraft).stub_mcsw_properties_fetch(200, p)
    sign_in @owner
    @server.update_columns(remote_id: 1)
    put :update_properties, params: {
      id: @server.id,
      minecraft_properties: {
        difficulty: 0,
        motd: 'A Gamocosm Minecraft Server',
      },
    }
    assert_redirected_to server_path(@server)
    assert_not_nil flash[:success], 'Updating minecraft properties not success'
  end

  test 'minecraft properties error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 0)
    p = {
      difficulty: '0',
      motd: 'A Gamocosm Minecraft Server',
    }
    mock_mcsw_properties_fetch(@server.minecraft).stub_mcsw_properties_fetch(400, p)
    sign_in @owner
    @server.update_columns(remote_id: 1)
    get :show, params: { id: @server.id }
    assert_response :success
    assert_select 'p', /error getting minecraft properties/i
  end

  test 'pause and resume minecraft' do
    mock_do_base(200)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1).times(1).stub_mcsw_pid(200, 0)
    mock_mcsw_stop(200, @server.minecraft)
    mock_mcsw_start(@server.minecraft).stub_mcsw_start(200, @server.ram)
    sign_in @friend
    @server.update_columns(remote_id: 1)
    get :pause, params: { id: @server.id }
    assert_redirected_to server_path(@server)
    assert_equal 'Server paused', flash[:success], 'Minecraft pause not successful'
    get :resume, params: { id: @server.id }
    assert_redirected_to server_path(@server)
    assert_equal 'Server resumed', flash[:success], 'Minecraft resume not successful'
  end

  test 'exec minecraft command' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1)
    mock_mcsw_exec(@server.minecraft).stub_mcsw_exec(200, 'help')
    sign_in @owner
    @server.update_columns(remote_id: 1)
    post :command, params: { id: @server.id, command: { data: 'help' } }
    assert_redirected_to server_path(@server)
    assert_equal 'Command sent', flash[:success], 'Minecraft exec command not successful'
  end

  test 'backup minecraft' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 0)
    mock_mcsw_backup(200, @server.minecraft)
    sign_in @friend
    @server.update_columns(remote_id: 1)
    post :backup, params: { id: @server.id }
    assert_redirected_to server_path(@server)
    assert_equal 'World backed up remotely on server', flash[:success], 'Minecraft backup not successful'
  end

  test 'edit advanced tab' do
    sign_in @owner
    # initial values
    view_server @server, {
      setup_stage: 0,
      remote_region_slug: 'nyc3',
      remote_size_slug: '512mb',
    }
    put :update, params: { id: @server.id, server: {
      setup_stage: 5,
      remote_size_slug: '1gb',
      remote_region_slug: ' nyc3 ',
    } }
    assert_redirected_to server_path(@server)
    # updated, trimmed values
    view_server @server, {
      setup_stage: 5,
      remote_region_slug: 'nyc3',
      remote_size_slug: '1gb',
    }
    put :update, params: { id: @server.id, server: {
      setup_stage: 0,
      remote_size_slug: ' 512mb ',
      remote_region_slug: 'nyc3',
    } }
    assert_redirected_to server_path(@server)
    # reset values
    view_server @server, {
      setup_stage: 0,
      remote_region_slug: 'nyc3',
      remote_size_slug: '512mb',
    }
    put :update, params: { id: @server.id, server: {
      size_slug: ' ',
      remote_region_slug: "\n",
    } }
    assert_response :success
    # required values
    assert_not_nil flash[:error], 'Advanced tab bad form, no error message'
  end

  test 'autoshutdown disable' do
    sign_in @owner
    begin
      @server.minecraft.update_columns(autoshutdown_enabled: true)
      get :autoshutdown_disable, params: { id: @server.id }
      assert_redirected_to server_path(@server)
      assert_equal 'Autoshutdown disabled', flash[:success], 'No success message about autoshutdown disabled'
      @server.reload
      assert_not @server.minecraft.autoshutdown_enabled
    ensure
      @server.minecraft.update_columns(autoshutdown_enabled: false)
    end
  end

  test 'edit ssh keys' do
    sign_in @owner
    view_server @server
    assert_select '#server_ssh_keys', 1
    assert_nil @server.ssh_keys, 'Server SSH keys were not default value'
    put :update, params: {
      id: @server.id,
      server: {
        ssh_keys: ' 123, 456 , 789',
      },
    }
    assert_redirected_to server_path(@server)
    view_server @server
    assert_select '#server_ssh_keys[value=?]', '123,456,789'
    put :update, params: {
      id: @server.id,
      server: {
        ssh_keys: "\t",
      },
    }
    assert_redirected_to server_path(@server)
    view_server @server
    assert_select '#server_ssh_keys'
    assert_nil @server.ssh_keys, 'Server SSH keys were not reset'
    put :update, params: {
      id: @server.id,
      server: {
        ssh_keys: '123,',
      },
    }
    assert_response :success
    assert_not_nil flash[:error], 'Updating ssh keys bad value, no error message'
  end

  test 'edit schedule tab' do
    sign_in @owner
    view_server @server
    assert_select '#server_timezone_delta', 1
    begin
      put :update, params: {
        id: @server.id,
        server: {
          timezone_delta: 3,
          minecraft_attributes: {
            autoshutdown_minutes: 16,
          },
          schedule_text: 'saturday 10:00 am start',
        }
      }
      assert_redirected_to server_path(@server)
      view_server @server
      assert_select '#server_timezone_delta[value=?]', '3'
      assert_select '#server_schedule_text', { text: 'Saturday 10:00 am start' }
      assert_select '#server_minecraft_attributes_autoshutdown_minutes[value=?]', '16'
    ensure
      @server.update_columns(timezone_delta: 0)
      @server.minecraft.update_columns(autoshutdown_minutes: 8)
      @server.scheduled_tasks.delete_all
    end
  end

  test 'busy page' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1)
    sign_in @friend
    begin
      @server.update_columns(remote_id: 1)
      @server.update_columns(pending_operation: 'starting')
      @server.update_columns(setup_stage: 0)
      @server.reload
      view_server @server
      ensure_busy
      assert_select 'div', /this should take a few minutes/i
      @server.update_columns(setup_stage: 5)
      view_server @server
      ensure_busy
      assert_select 'div', /this should take about a minute/i
      @server.update_columns(pending_operation: 'preparing')
      [
        /connecting/i,
        /installing and updating software/i,
        /adding ssh keys/i,
        /downloading and installing minecraft/i,
        /finishing up/i,
        /keeping the system up to date/i,
      ].each_with_index do |x, i|
        @server.update_columns(setup_stage: i)
        view_server @server
        ensure_busy
        assert_select 'div', x
      end
      @server.update_columns(pending_operation: 'stopping')
      view_server @server
      ensure_busy
      assert_select 'div', /your server is shutting down/i
      @server.update_columns(pending_operation: 'saving')
      view_server @server
      ensure_busy
      assert_select 'div', /your server is being backed up/i
      @server.update_columns(pending_operation: 'rebooting')
      view_server @server
      ensure_busy
      assert_select 'div', /your server is rebooting/i
    ensure
      @server.update_columns(remote_id: nil, pending_operation: nil, setup_stage: 0)
    end
  end

  test 'log message and clear' do
    sign_in @owner
    view_server @server
    assert_select '.panel-body em', 'No messages'
    @server.log_test('Hello')
    view_server @server
    assert_select '.panel-body div', /Hello/
    get :clear_logs, params: { id: @server.id }
    assert_redirected_to server_path(@server)
    view_server @server
    assert_not_nil flash[:success], 'Clearing server logs not success'
    assert_select '.panel-body em', 'No messages'
  end

  test 'friend cannot delete, edit advanced tab, edit ssh keys' do
    sign_in @friend
    assert_raises(ActionController::RoutingError) do
      delete :destroy, params: { id: @server.id }
    end
    assert_raises(ActionController::RoutingError) do
      put :update, params: { id: @server.id, server: {
        setup_stage: 5,
        remote_size_slug: '1gb',
        remote_region_slug: ' nyc3 ',
      } }
    end
    assert_raises(ActionController::RoutingError) do
      put :update, params: { id: @server.id, server: { ssh_keys: '123' } }
    end
  end

  test 'other users see 404' do
    sign_in @other
    assert_raises(ActionController::RoutingError) do
      get :show, params: { id: @server.id }
      assert_redirected_to new_user_session_path
    end
  end

  test 'outsiders redirected to login' do
    get :show, params: { id: @server.id }
    assert_redirected_to new_user_session_path
  end

  def view_server(server, advanced_tab = { })
    mock_mcsw_properties_fetch(server.minecraft).stub_mcsw_properties_fetch(200, { }).times_only(1)
    get :show, params: { id: server.id }
    assert_response :success
    advanced_tab.each do |k, v|
      assert_select "#server_#{k}[value=\"#{v}\"]"
    end
  end

  def start_server(server)
    get :start, params: { id: server.id }
    assert_redirected_to server_path(server)
    view_server(server)
    assert_equal 'Server starting', flash[:success]
    ensure_busy
    assert_equal 1, WaitForStartingServerWorker.jobs.count, 'No wait for starting server worker after start'
    WaitForStartingServerWorker.jobs.clear
    server.reload
  end

  def stop_server(server)
    get :stop, params: { id: server.id }
    assert_redirected_to server_path(server)
    view_server(server)
    assert_equal 'Server stopping', flash[:success]
    ensure_busy
    assert_equal 1, WaitForStoppingServerWorker.jobs.count, 'No wait for stopping server worker after stop'
    WaitForStoppingServerWorker.jobs.clear
    server.reload
  end

  def ensure_busy
    assert_select 'meta[http-equiv=refresh]', { count: 1 }
  end

  def add_friend_to_server(server, friend)
    post :add_friend, params: { id: server.id, server_friend: { email: friend.email } }
    assert_redirected_to server_path(server)
    view_server server
    assert_not_nil flash[:success], 'Add friend to server not success'
    assert_select '.friend .email', friend.email
  end

  def remove_friend_from_server(server, friend)
    post :remove_friend, params: { id: server, server_friend: { email: friend.email } }
    assert_redirected_to server_path(server)
    view_server server
    assert_not_nil flash[:success], 'Remove friend from server not success'
    assert_select '.friend .email', { text: friend.email, count: 0 }
  end

  test 'destroy digital ocean droplet' do
    mock_do_base(200)
    mock_do_droplet_delete(200, 1)
    sign_in @owner
    post :destroy_digital_ocean_droplet, params: { id: 1 }
    assert_redirected_to servers_path
    get :index
    assert_response :success
    assert_match /deleted droplet/i, flash[:notice], 'Something went wrong deleting Digital Ocean droplet from Digital Ocean control panel'
  end

  test 'destroy digital ocean snapshot' do
    mock_do_base(200)
    mock_do_image_delete(200, 1)
    sign_in @owner
    post :destroy_digital_ocean_snapshot, params: { id: 1 }
    assert_redirected_to servers_path
    get :index
    assert_response :success
    assert_match /deleted snapshot/i, flash[:notice], 'Something went wrong deleting Digital Ocean snapshot from Digital Ocean control panel'
  end

  test 'add digital ocean ssh key' do
    mock_do_ssh_key_add().stub_do_ssh_key_add(200, 'me', 'a b c')
    sign_in @owner
    request.host = 'example.com'
    request.env['HTTP_REFERER'] = server_path(@server)
    post :add_digital_ocean_ssh_key, params: {
      id: @server.id,
      digital_ocean_ssh_key: {
        name: 'me',
        data: 'a b c',
      },
    }
    assert_redirected_to server_path(@server)
    assert_match /added ssh public key/i, flash[:success], 'Adding Digital Ocean SSH key not success'
  end

  test 'destroy digital ocean ssh key' do
    mock_do_ssh_key_delete(204, 1)
    sign_in @owner
    request.host = 'example.com'
    request.env['HTTP_REFERER'] = server_path(@server)
    post :destroy_digital_ocean_ssh_key, params: {
      id: 1,
    }
    assert_redirected_to server_path(@server)
    assert_match /deleted ssh public key/i, flash[:success], 'Deleting Digital Ocean SSH key not success'
  end

  test 'add/destroy digital ocean ssh key no referer' do
    mock_do_base(200)
    mock_do_ssh_key_add().stub_do_ssh_key_add(200, 'me', 'a b c')
    mock_do_ssh_key_delete(204, 1)
    sign_in @owner
    post :add_digital_ocean_ssh_key, params: {
      digital_ocean_ssh_key: {
        name: 'me',
        data: 'a b c',
      },
    }
    assert_redirected_to servers_path
    assert_match /added ssh public key/i, flash[:success], 'Adding Digital Ocean SSH key not success'
    post :destroy_digital_ocean_ssh_key, params: {
      id: 1,
    }
    assert_redirected_to servers_path
    assert_match /deleted ssh public key/i, flash[:success], 'Deleting Digital Ocean SSH key not success'
  end

  test 'show digital ocean droplets' do
    sign_in @friend
    get :show_digital_ocean_droplets
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_droplets_list(200, []).times_only(1)
    get :show_digital_ocean_droplets
    assert_response :success
    assert_select 'em', /you have no droplets on digital ocean/i

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_droplets_list(200, [
      {
        id: 1,
        name: 'abc',
        created_at: DateTime.current.to_s,
        snapshot_ids: [],
        networks: {
          v4: [
            { type: 'public', ip_address: 'localhost' },
          ],
        },
      },
    ]).times_only(1)
    get :show_digital_ocean_droplets
    assert_response :success
    assert_select 'td', /abc/

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_droplets_list(401, []).times_only(1)
    get :show_digital_ocean_droplets
    assert_response :success
    assert_select 'em', /unable to get digital ocean droplets/i
  end

  test 'show digital ocean snapshots' do
    sign_in @friend
    get :show_digital_ocean_snapshots
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_images_list(200, []).times_only(1)
    get :show_digital_ocean_snapshots
    assert_response :success
    assert_select 'em', /you have no snapshots on digital ocean/i

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_images_list(200, [
      {
        id: 1,
        name: 'def',
        created_at: DateTime.current.to_s,
      },
    ]).times_only(1)
    get :show_digital_ocean_snapshots
    assert_response :success
    assert_select 'td', /def/

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_images_list(401, []).times_only(1)
    get :show_digital_ocean_snapshots
    assert_response :success
    assert_select 'em', /unable to get digital ocean snapshots/i
  end

  test 'show digital ocean ssh keys' do
    sign_in @friend
    get :show_digital_ocean_ssh_keys
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_ssh_keys_list(200, []).times_only(1)
    get :show_digital_ocean_ssh_keys
    assert_response :success
    assert_select 'em', /you have no ssh keys on digital ocean/i

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_ssh_keys_list(200, [
      {
        id: 1,
        name: 'ghi',
      },
    ]).times_only(1)
    get :show_digital_ocean_ssh_keys
    assert_response :success
    assert_select 'td', 'ghi'

    delete :refresh_digital_ocean_cache
    assert_redirected_to servers_path
    mock_do_ssh_keys_list(401, []).times_only(1)
    get :show_digital_ocean_ssh_keys
    assert_response :success
    assert_select 'em', /unable to get digital ocean ssh keys/i
  end
end
