User.delete_all
ActiveRecord::Base.connection.reset_pk_sequence!(:users)

user = User.new
user.email = 'test@test.com'
user.password = '1234test'
user.password_confirmation = user.password
user.digital_ocean_api_key = Gamocosm.digital_ocean_api_key
user.save!

user = User.new
user.email = 'test2@test.com'
user.password = '2345test'
user.password_confirmation = user.password
user.save!
