require 'test_helper'

class MinecraftsControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  def setup
    @owner = User.find(1)
    @friend = User.find(2)
    @other = User.find(3)
    @minecraft = Minecraft.first
  end

  def teardown
    assert_equal 0, Sidekiq::Worker.jobs.count, 'Unexpected Sidekiq jobs remain'
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
    #start_server @minecraft
    #stop_minecraft @minecraft
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
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { ssh_keys: ' 123, 456 , 789' } } }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_select '#minecraft_server_attributes_ssh_keys[value=?]', '123,456,789'
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { ssh_keys: "\t" } } }
    assert_redirected_to minecraft_path(@minecraft)
    view_server @minecraft
    assert_select '#minecraft_server_attributes_ssh_keys'
    assert_nil @minecraft.server.ssh_keys, 'Minecraft SSH keys were not reset'
    put :update, { id: @minecraft.id, minecraft: { server_attributes: { ssh_keys: '123,' } } }
    assert_response :success
    assert_not_nil flash[:error]
  end

  test 'friend cannot delete, edit advanced tab, ssh keys' do
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

  test 'outsider needs login' do
    get :show, { id: @minecraft.id }
    assert_redirected_to new_user_session_path
  end

  test 'other users see 404' do
    sign_in @other
    assert_raises(ActionController::RoutingError) do
      get :show, { id: @minecraft.id }
      assert_redirected_to new_user_session_path
    end
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
    assert_not_nil flash[:success]
    assert_equal 1, WaitForStartingServerWorker.jobs.count, 'No wait for starting server worker'
    WaitForStartingServerWorker.jobs.clear
    ensure_busy
  end

  def stop_server(minecraft)
    get :stop, { id: minecraft.id }
    assert_redirected_to minecraft_path(@minecraft)
    view_server(minecraft)
    assert_not_nil flash[:success]
    assert_equal 1, WaitForStoppingServerWorker.jobs.count, 'No wait for stopping server worker'
    WaitForStoppingServerWorker.jobs.clear
    ensure_busy
  end

  def ensure_busy
    assert_select 'meta[http-equiv=refresh]', { count: 0 }
  end

  def add_friend_to_server(minecraft, friend)
    post :add_friend, { id: minecraft.id, minecraft_friend: { email: friend.email } }
    assert_redirected_to minecraft_path(minecraft)
    view_server minecraft
    assert_not_nil flash[:success]
    assert_select 'td', friend.email
  end

  def remove_friend_from_server(minecraft, friend)
    post :remove_friend, { id: minecraft.id, minecraft_friend: { email: friend.email } }
    assert_redirected_to minecraft_path(minecraft)
    view_server minecraft
    assert_not_nil flash[:success]
    assert_select 'td', { text: friend.email, count: 0 }
  end

end
