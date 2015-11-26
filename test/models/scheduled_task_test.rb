# == Schema Information
#
# Table name: scheduled_tasks
#
#  id        :integer          not null, primary key
#  server_id :uuid             not null
#  partition :integer          not null
#  action    :string           not null
#

require 'test_helper'

class ScheduledTaskTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
