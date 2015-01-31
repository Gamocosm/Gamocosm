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
user.update_columns(digital_ocean_api_key: Gamocosm.digital_ocean_api_key)

mc = Minecraft.new
mc.name = 'test'
mc.user = User.find(1)
mc.flavour = Gamocosm.minecraft_flavours.first[0]

server = Server.new
server.do_region_slug = 'nyc3'
server.do_size_slug = '512mb'
mc.server = server

mc.friends << User.find(2)

mc.save!
