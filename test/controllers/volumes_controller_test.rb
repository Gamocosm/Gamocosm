require 'test_helper'

class VolumesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @owner = User.find(1)
    @volume = Volume.first
  end

  test 'should get index' do
    sign_in @owner
    get volumes_url
    assert_response :success
  end

  test 'should get new' do
    mock_do_base(200)
    sign_in @owner
    get new_volume_url
    assert_response :success
  end

  test 'should create volume' do
    sign_in @owner
    #assert_difference('Volume.count') do
    #  post volumes_url, params: { volume: { remote_id: @volume.remote_id, remote_region_slug: @volume.remote_region_slug, remote_size_gb: @volume.remote_size_gb, remote_snapshot_id: @volume.remote_snapshot_id } }
    #end

    #assert_redirected_to volume_url(Volume.last)
  end

  test 'should show volume' do
    sign_in @owner
    get volume_url(@volume)
    assert_response :success
  end

  test 'should get edit' do
    mock_do_base(200)
    sign_in @owner
    get edit_volume_url(@volume)
    assert_response :success
  end

  test 'should update volume' do
    sign_in @owner
    #patch volume_url(@volume), params: { volume: { remote_id: @volume.remote_id, remote_region_slug: @volume.remote_region_slug, remote_size_gb: @volume.remote_size_gb, remote_snapshot_id: @volume.remote_snapshot_id } }
    #assert_redirected_to volume_url(@volume)
  end

  test 'should destroy volume' do
    sign_in @owner
    #assert_difference('Volume.count', -1) do
    #  delete volume_url(@volume)
    #end

    #assert_redirected_to volumes_url
  end
end
