# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

if Rails.env.development?
  user = User.new
  user.email = 'test@test.com'
  user.password = '1234test'
  user.password_confirmation = user.password
  user.digital_ocean_api_key = Gamocosm.digital_ocean_api_key
  user.save!
end
