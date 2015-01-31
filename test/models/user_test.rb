# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  email                  :string(255)      default(""), not null
#  encrypted_password     :string(255)      default(""), not null
#  reset_password_token   :string(255)
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :string(255)
#  last_sign_in_ip        :string(255)
#  created_at             :datetime
#  updated_at             :datetime
#  digital_ocean_api_key  :string(255)
#

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test 'validate user' do
    a = User.new
    a.digital_ocean_api_key = " AB\n\0 "
    assert_not a.valid?, 'User passed bad validation'
    assert_equal 'ab', a.digital_ocean_api_key, 'Digital Ocean API key not sanitized'
    a.digital_ocean_api_key = nil
    assert_not a.valid?, 'User passed bad validation'
    assert_nil a.digital_ocean_api_key, 'Digital Ocean API key should be blank -> nil'
    a.digital_ocean_api_key = " \r\t\0 "
    assert_not a.valid?, 'User passed bad validation'
    assert_nil a.digital_ocean_api_key, 'Digital Ocean API key should be strip -> blank -> nil'
  end
end
