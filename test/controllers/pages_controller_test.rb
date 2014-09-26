require 'test_helper'

class PagesControllerTest < ActionController::TestCase
  include Devise::TestHelpers

  test "front page does not crash :)" do
    get :landing
    assert_response :success
  end

end
