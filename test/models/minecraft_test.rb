# == Schema Information
#
# Table name: minecrafts
#
#  id                           :integer          not null, primary key
#  created_at                   :datetime
#  updated_at                   :datetime
#  server_id                    :uuid             not null
#  flavour                      :string           not null
#  mcsw_password                :string           not null
#  autoshutdown_enabled         :boolean          default(FALSE), not null
#  autoshutdown_last_check      :datetime         not null
#  autoshutdown_last_successful :datetime         not null
#  autoshutdown_minutes         :integer          default(8), not null
#

require 'test_helper'

class MinecraftTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  def setup
    @minecraft = Minecraft.first
  end

  def teardown
  end
end
