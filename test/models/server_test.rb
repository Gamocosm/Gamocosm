# == Schema Information
#
# Table name: servers
#
#  id                           :integer          not null, primary key
#  created_at                   :datetime
#  updated_at                   :datetime
#  minecraft_id                 :uuid             not null
#  flavour                      :string           not null
#  mcsw_password                :string           not null
#  autoshutdown_enabled         :boolean          default("false"), not null
#  autoshutdown_last_check      :datetime         not null
#  autoshutdown_last_successful :datetime         not null
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
