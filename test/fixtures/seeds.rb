User.delete_all
ActiveRecord::Base.connection.reset_pk_sequence!(:users)

{
  'test@test.com' => '1234test',
  'test2@test.com' => '2345test',
  'test3@test.com' => '3456test',
}.each do |k, v|
  user = User.new
  user.email = k
  user.password = v
  user.password_confirmation = user.password
  user.save!
end

user = User.first
user.update_columns(digital_ocean_api_key: Gamocosm::DIGITAL_OCEAN_API_KEY)

s = Server.new
s.name = 'test'
s.user = user
s.remote_region_slug = 'nyc3'
s.remote_size_slug = 's-1vcpu-1gb'

mc = Minecraft.new
mc.flavour = Gamocosm::MINECRAFT_FLAVOURS.first[0]

s.minecraft = mc

s.friends << User.find(2)

s.save!

v = Volume.new
v.user = user
v.name = 'test-volume'
v.status = 'volume'
v.remote_size_gb = 4
v.remote_region_slug = 'nyc3'
v.save!
