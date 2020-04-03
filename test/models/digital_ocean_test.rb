require 'test_helper'

class DigitalOceanTest < ActiveSupport::TestCase

  def setup
    @con = DigitalOcean::Connection.new('abc')
  end

  test 'no api token' do
    c = DigitalOcean::Connection.new(nil)
    res = c.droplet_list
    assert res.error?
    assert_equal 'You have not entered your Digital Ocean API token', res.msg
  end

  test 'size list' do
    mock_digital_ocean(:get, '/sizes')
      .stub_do_list
      .to_timeout.times_only(2)
    res = @con.size_list_uncached
    assert res.error?
    #assert_match 'Digital Ocean API network exception: execution expired', res.msg
    assert_match /execution expired/, res.msg
    res = @con.size_list
    assert_equal DigitalOcean::Size::DEFAULT_SIZES, res
  end

  test 'region list' do
    mock_do_base(400)
    res = @con.region_list_uncached
    assert res.error?
    assert_match /Digital Ocean API HTTP response status not ok: 400: /, res.msg
    res = @con.region_list
    assert_equal DigitalOcean::Region::DEFAULT_REGIONS, res
  end

  test 'region find' do
    mock_do_base(200)
    res = @con.region_find('nyc3')
    assert_equal 'New York 3', res.name
  end
end
