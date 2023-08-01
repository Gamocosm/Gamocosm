require 'test_helper'

class PageFlowsTest < ActionDispatch::IntegrationTest
  test 'non-existing pages' do
    get '/foobar'
    assert_response :missing
  end
end
