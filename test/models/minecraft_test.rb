# == Schema Information
#
# Table name: minecrafts
#
#  id                           :uuid             not null, primary key
#  user_id                      :integer          not null
#  name                         :string(255)      not null
#  created_at                   :datetime
#  updated_at                   :datetime
#  minecraft_wrapper_password   :string(255)      not null
#  autoshutdown_enabled         :boolean          default("false"), not null
#  autoshutdown_last_check      :datetime
#  autoshutdown_last_successful :datetime
#  flavour                      :string(255)      default("vanilla/null"), not null
#  domain                       :string           not null
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

  test 'log messages' do
  end
end
