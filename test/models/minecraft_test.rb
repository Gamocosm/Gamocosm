# == Schema Information
#
# Table name: minecrafts
#
#  id                 :uuid             not null, primary key
#  user_id            :integer          not null
#  name               :string(255)      not null
#  created_at         :datetime
#  updated_at         :datetime
#  domain             :string           not null
#  pending_operation  :string
#  ssh_port           :integer          default("4022"), not null
#  ssh_keys           :string
#  setup_stage        :integer          default("0"), not null
#  remote_id          :integer
#  remote_region_slug :string           not null
#  remote_size_slug   :string           not null
#  remote_snapshot_id :integer
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
