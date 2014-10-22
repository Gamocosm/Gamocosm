# == Schema Information
#
# Table name: server_logs
#
#  id           :integer          not null, primary key
#  minecraft_id :uuid             not null
#  message      :text             not null
#  debuginfo    :string(255)      not null
#  created_at   :datetime
#  updated_at   :datetime
#

require 'test_helper'

class ServerLogTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
