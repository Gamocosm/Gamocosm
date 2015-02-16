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
#  remote_setup_stage   :integer          default("0"), not null
#  pending_operation    :string(255)
#  ssh_keys             :string(255)
#  ssh_port             :integer          default("4022"), not null
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
end
