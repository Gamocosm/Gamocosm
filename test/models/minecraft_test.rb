# == Schema Information
#
# Table name: minecrafts
#
#  id                         :uuid             not null, primary key
#  user_id                    :integer          not null
#  name                       :string(255)      not null
#  created_at                 :datetime
#  updated_at                 :datetime
#  minecraft_wrapper_password :string(255)      not null
#

require 'test_helper'

class MinecraftTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
