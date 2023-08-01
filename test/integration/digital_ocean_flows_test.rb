require 'test_helper'

class DigitalOceanFlowsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.find(1)
    @friend = User.find(2)
    @server = Server.first
  end

  test 'destroy digital ocean droplet' do
    mock_do_base(200)
    mock_do_droplet_delete(200, 1)
    sign_in @owner
    delete digital_ocean_droplet_path(1)
    assert_redirected_to servers_path
    get servers_path
    assert_response :success
    assert_match /deleted droplet/i, flash[:notice], 'Something went wrong deleting Digital Ocean droplet from Digital Ocean control panel'
  end

  test 'destroy digital ocean snapshot' do
    mock_do_base(200)
    mock_do_image_delete(200, 1)
    sign_in @owner
    delete digital_ocean_image_path(1)
    assert_redirected_to servers_path
    get servers_path
    assert_response :success
    assert_match /deleted snapshot/i, flash[:notice], 'Something went wrong deleting Digital Ocean snapshot from Digital Ocean control panel'
  end

  test 'add digital ocean ssh key' do
    mock_do_ssh_key_add.stub_do_ssh_key_add(200, 'me', 'a b c')
    sign_in @owner
    post digital_ocean_ssh_keys_path, params: {
      digital_ocean_ssh_key: {
        name: 'me',
        data: 'a b c',
      },
    }, headers: {
      'HTTP_REFERER' => server_path(@server),
    }
    assert_redirected_to server_path(@server)
    assert_match /added ssh public key/i, flash[:success], 'Adding Digital Ocean SSH key not success'
  end

  test 'destroy digital ocean ssh key' do
    mock_do_ssh_key_delete(204, 1)
    sign_in @owner
    delete digital_ocean_ssh_key_path(1), headers: {
      'HTTP_REFERER' => server_path(@server),
    }
    assert_redirected_to server_path(@server)
    assert_match /deleted ssh public key/i, flash[:success], 'Deleting Digital Ocean SSH key not success'
  end

  test 'add/destroy digital ocean ssh key no referer' do
    mock_do_base(200)
    mock_do_ssh_key_add.stub_do_ssh_key_add(200, 'me', 'a b c')
    mock_do_ssh_key_delete(204, 1)
    sign_in @owner
    post digital_ocean_ssh_keys_path, params: {
      digital_ocean_ssh_key: {
        name: 'me',
        data: 'a b c',
      },
    }
    assert_redirected_to servers_path
    assert_match /added ssh public key/i, flash[:success], 'Adding Digital Ocean SSH key not success'
    delete digital_ocean_ssh_key_path(1)
    assert_redirected_to servers_path
    assert_match /deleted ssh public key/i, flash[:success], 'Deleting Digital Ocean SSH key not success'
  end

  test 'show digital ocean droplets' do
    sign_in @friend
    get digital_ocean_droplets_path
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_droplets_list(200, []).times_only(1)
    get digital_ocean_droplets_path
    assert_response :success
    assert_select 'em', /you have no droplets on digital ocean/i

    delete digital_ocean_refresh_cache_path
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
    get digital_ocean_droplets_path
    assert_response :success
    assert_select 'td', /abc/

    delete digital_ocean_refresh_cache_path
    assert_redirected_to servers_path
    mock_do_droplets_list(401, []).times_only(1)
    get digital_ocean_droplets_path
    assert_response :success
    assert_select 'em', /unable to get digital ocean droplets/i
  end

  test 'show digital ocean snapshots' do
    sign_in @friend
    get digital_ocean_images_path
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_images_list(200, []).times_only(1)
    get digital_ocean_images_path
    assert_response :success
    assert_select 'em', /you have no snapshots on digital ocean/i

    delete digital_ocean_refresh_cache_path
    assert_redirected_to servers_path
    mock_do_images_list(200, [
      {
        id: 1,
        name: 'def',
        created_at: DateTime.current.to_s,
      },
    ]).times_only(1)
    get digital_ocean_images_path
    assert_response :success
    assert_select 'td', /def/

    delete digital_ocean_refresh_cache_path
    assert_redirected_to servers_path
    mock_do_images_list(401, []).times_only(1)
    get digital_ocean_images_path
    assert_response :success
    assert_select 'em', /unable to get digital ocean droplet snapshots/i
  end

  test 'show digital ocean ssh keys' do
    sign_in @friend
    get digital_ocean_ssh_keys_path
    assert_response :success
    assert_select 'em', /you haven't entered your digital ocean api token/i
    sign_out @friend

    sign_in @owner
    mock_do_ssh_keys_list(200, []).times_only(1)
    get digital_ocean_ssh_keys_path
    assert_response :success
    assert_select 'em', /you have no ssh keys on digital ocean/i

    delete digital_ocean_refresh_cache_path
    assert_redirected_to servers_path
    mock_do_ssh_keys_list(200, [
      {
        id: 1,
        name: 'ghi',
      },
    ]).times_only(1)
    get digital_ocean_ssh_keys_path
    assert_response :success
    assert_select 'td', 'ghi'

    delete digital_ocean_refresh_cache_path
    assert_redirected_to servers_path
    mock_do_ssh_keys_list(401, []).times_only(1)
    get digital_ocean_ssh_keys_path
    assert_response :success
    assert_select 'em', /unable to get digital ocean ssh keys/i
  end
end
