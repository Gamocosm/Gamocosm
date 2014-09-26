require 'test_helper'

class MinecraftFlowsTest < ActionDispatch::IntegrationTest
  # test "the truth" do
  #   assert true
  # end

  def setup
  end

  def teardown
  end

  test "create server, start server, stop server, start server, delete server" do
    post_via_redirect user_session_path, { user: { email: 'test@test.com', password: '1234test' } }
    assert_response :success
  end

  def wait_for_starting_server(times = 0)
  end

  def wait_for_stopping_server(times = 0)
  end
end
