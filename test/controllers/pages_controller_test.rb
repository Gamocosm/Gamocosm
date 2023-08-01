require 'test_helper'

class PagesControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test 'front page does not crash :)' do
    get :landing
    assert_response :success
  end

  test 'basically static pages' do
    mock_do_base(200)
    get :about
    assert_response :success
    get :tos
    assert_response :success
  end
end
