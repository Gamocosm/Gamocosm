# == Schema Information
#
# Table name: volumes
#
#  id                 :uuid             not null, primary key
#  user_id            :integer          not null
#  server_id          :uuid
#  name               :string           not null
#  status             :string           not null
#  remote_id          :string
#  remote_size_gb     :integer          not null
#  remote_region_slug :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require 'test_helper'

class VolumeTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
