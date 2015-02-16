#ifndef __SERVER_TEST_RB_
#define __SERVER_TEST_RB_
# == Schema Information
#
# Table name: servers
#
#  id                   :integer          not null, primary key
#  remote_id            :integer
#  created_at           :datetime
#  updated_at           :datetime
#  minecraft_id         :uuid             not null
#  do_region_slug       :string(255)      not null
#  do_size_slug         :string(255)      not null
#  do_saved_snapshot_id :integer
#  remote_setup_stage   :integer          default(0), not null
#  pending_operation    :string(255)
#  ssh_keys             :string(255)
#  ssh_port             :integer          default(4022), not null
#

require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  def setup
    @minecraft = Minecraft.first
  end

  test 'invalid ram' do
    ServerLog.delete_all
    mock_do_base(200)
    old_size = @minecraft.server.do_size_slug
    @minecraft.server.do_size_slug = 'badness'
    x = @minecraft.server.ram
    assert_equal 512, x, 'Server should have selected default 512MB of RAM'
    assert_equal 1, @minecraft.logs.count, 'Should have 1 log message'
    assert_equal 'Unknown Digital Ocean size slug badness; only starting server with 512MB of RAM', @minecraft.logs.first.message, 'Should have log message about bad size setting'
    @minecraft.reload
    assert_equal old_size, @minecraft.server.do_size_slug, 'Server size slug should not have saved'
  end

  test 'refresh domain' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_cloudflare.stub_cf_dns_list(200, 'success', []).times_only(1)
    mock_cloudflare.stub_cf_dns_add(200, 'success', 'abcdefgh', 'localhost').times_only(1)
    if !@minecraft.server.server_domain.nil?
      @minecraft.server.server_domain.destroy
      @minecraft.reload
    end
    begin
      # ensure loaded before patching
      ServerDomain
      class ::ServerDomain
        alias_method :random_name_unpatched, :random_name
        def random_name
          'abcdefgh'
        end
      end
      @minecraft.server.update_columns(remote_id: 1)
      x = @minecraft.server.refresh_domain
      assert_nil x, "Failed to refresh server domain: #{x}"
    ensure
      class ::ServerDomain
        def random_name
          random_name_unpatched
        end
      end
      @minecraft.reload
      @minecraft.server.server_domain.destroy
      @minecraft.server.update_columns(remote_id: nil)
    end
  end

  test 'refresh domain remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, 'active').times_only(1)
    begin
      @minecraft.server.update_columns(remote_id: 1)
      res = @minecraft.server.refresh_domain
      assert res.error?, 'Should have error refreshing domain'
      assert_match /Digital Ocean API error: HTTP response status not ok, was 400/, res, 'Should have error about Digital Ocean request'
    ensure
      @minecraft.server.update_columns(remote_id: nil)
    end
  end
end
#endif /* __SERVER_TEST_RB_ */
