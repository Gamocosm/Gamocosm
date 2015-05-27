require 'test_helper'

class CloudFlareTest < ActiveSupport::TestCase

  def setup
    @cloudflare = CloudFlare::Client.new(Gamocosm::CLOUDFLARE_EMAIL, Gamocosm::CLOUDFLARE_API_TOKEN, Gamocosm::USER_SERVERS_DOMAIN)
  end

  def teardown
  end

  test 'error responses' do
    mock_cloudflare.stub_cf_dns_list(400, 'success', []).times_only(1)
    res = @cloudflare.dns_list
    assert res.error?, 'CloudFlare response should have been an error 400'
    assert_equal 'CloudFlare API error: HTTP response code 400, {"result"=>"success", "response"=>{"recs"=>{"objs"=>[]}}}', res.msg

    mock_cloudflare.stub_cf_dns_add(500, 'success', 'abc', 'localhost').times_only(1)
    res = @cloudflare.dns_add('abc', 'localhost')
    assert res.error?, 'CloudFlare response should have been an error 500'
    assert_match /cloudflare api error: http response code 500, {/i, res.msg

    mock_cloudflare.stub_cf_dns_list(200, 'not_sucess', [
      { rec_id: 1, display_name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_update('abc', 'localhost')
    assert res.error?, 'CloudFlare response should have been result not success'
    assert_equal 'CloudFlare API error: response result not_sucess, {"result"=>"not_sucess", "response"=>{"recs"=>{"objs"=>[{"rec_id"=>1, "display_name"=>"abc", "type"=>"A"}]}}}', res.msg

    mock_cloudflare.stub_cf_dns_edit(200, 'not_success', 1, 'abc', 'localhost').times_only(1)
    mock_cloudflare.stub_cf_dns_list(200, 'success', [
      { rec_id: 1, display_name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_update('abc', 'localhost')
    assert res.error?, 'CloudFlare response should have been result not success'
    assert_equal 'CloudFlare API error: response result not_success, {"result"=>"not_success", "response"=>{}}', res.msg

    mock_cloudflare.stub_cf_dns_list(200, 'not_success', [
      { rec_id: 1, display_name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_delete('abc')
    assert res.error?, 'CloudFlare response should have been result not success'
    assert_match /cloudflare api error: response result not_success/i, res.msg

    mock_cloudflare.stub_cf_dns_delete(400, 'success', 1)
    mock_cloudflare.stub_cf_dns_list(200, 'success', [
      { rec_id: 1, display_name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_delete('abc')
    assert res.error?, 'CloudFlare response should have been an error 400'
    assert_equal 'CloudFlare API error: HTTP response code 400, {"result"=>"success", "response"=>{}}', res.msg
  end

  test 'update dns will add if not found' do
    mock_cloudflare.stub_cf_dns_list(200, 'success', []).times_only(1)
    mock_cloudflare.stub_cf_dns_add(200, 'success', 'abc', 'localhost').times_only(1)
    res = @cloudflare.dns_update('abc', 'localhost')
    assert_nil res, 'CloudFlare response should have been nil (no error)'
  end

  test 'delete non-existing domain ok' do
    mock_cloudflare.stub_cf_dns_list(200, 'success', [
      { rec_id: 1, display_name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_delete('def')
    assert_nil res, 'CloudFlare response should have been ok'
  end

  test 'http timeout' do
    mock_cloudflare.stub_cf_request('rec_load_all', {}).to_timeout
    res = @cloudflare.dns_list
    assert res.error?, 'CloudFlare response should have been a network exception'
    assert_equal 'CloudFlare API network exception: execution expired', res.msg
  end
end
