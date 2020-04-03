require 'test_helper'

class CloudFlareTest < ActiveSupport::TestCase

  def setup
    @cloudflare = CloudFlare::Client.new(Gamocosm::CLOUDFLARE_EMAIL, Gamocosm::CLOUDFLARE_API_TOKEN, Gamocosm::USER_SERVERS_DOMAIN, Gamocosm::CLOUDFLARE_ZONE)
  end

  def teardown
  end

  test 'error responses' do
    mock_cf_dns_list(400, true, []).times_only(1)
    res = @cloudflare.dns_list(nil)
    assert res.error?, 'CloudFlare response should have been an error 400'
    assert_match /CloudFlare API error: HTTP response code 400, /, res.msg

    mock_cf_dns_add(500, true, 'abc', 'localhost').times_only(1)
    res = @cloudflare.dns_add('abc', 'localhost')
    assert res.error?, 'CloudFlare response should have been an error 500'
    assert_match /cloudflare api error: http response code 500, {/i, res.msg

    mock_cf_dns_list(200, false, [
      { id: 1, name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_delete('abc')
    assert res.error?, 'CloudFlare response should have been result not success'
    assert_match /cloudflare api error: response result /i, res.msg

    mock_cf_dns_delete(400, true, 1)
    mock_cf_dns_list(200, true, [
      { id: 1, name: 'abc', type: 'A' },
    ]).times_only(1)
    res = @cloudflare.dns_delete('abc')
    assert res.error?, 'CloudFlare response should have been an error 400'
    assert_match 'CloudFlare API error: had 1 errors deleting DNS records.', res.msg
  end

  test 'delete non-existing domain ok' do
    mock_cf_dns_list(200, true, [
    #  { id: 1, name: 'abc', type: 'A' },
    ], 'def').times_only(1)
    res = @cloudflare.dns_delete('def')
    assert_nil res, 'CloudFlare response should have been ok'
  end

  test 'http timeout' do
    mock_cloudflare(:get).to_timeout
    res = @cloudflare.dns_list(nil)
    assert res.error?, 'CloudFlare response should have been a network exception'
    assert_equal 'CloudFlare API network exception: execution expired.', res.msg
  end
end
