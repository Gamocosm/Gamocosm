Gamocosm
========

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

### Minecraft Server Wrapper
The [Minecraft Server Wrapper][4] (for lack of a better name) is a light python webserver.
It provides an HTTP API for starting and stopping Minecraft servers, downloading the world, etc.
Please check it out and help improve it too!

### Contributing
Pull requests are welcome!

#### Setting up your development environment
You should have a Unix/Linux system.
The following instructions were made for Fedora 20, but the steps should be similar on other distributions.

1. Install postgresql and development headers and libraries, memcached, and redis: `(sudo) yum install postgresql-server postgresql-contrib postgresql-devel memcached redis`
1. Install Ruby 2.0.0+: `(sudo) yum install ruby`. You can also use RVM
1. Install Bundler: `gem install bundler`
1. Install gem dependencies: `bundle install`
1. Run `cp env.sh.template env.sh`
1. Run `chmod u+x env.sh`
1. Enter config in `env.sh`
1. Start postgresql, memcached, and redis manually: `(sudo) service start postgresql/memcached/redis`, or enable them to start at boot time: `(sudo) service enable postgresql/memcached/redis`
1. After configuring the database, run `./env.sh rake db:setup`
1. Start the server: `./env.sh rails s`
1. Start the Sidekiq worker: `./env.sh sidekiq`

##### env.sh options

- `DIGITAL_OCEAN_API_KEY`: your Digital Ocean api token
- `DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH`: ssh key to be added to new servers to SSH into
- `DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH`: see above
- `DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE`: see above
- `SIDEKIQ_ADMIN_USERNAME`: HTTP basic auth for Sidekiq web interface
- `SIDEKIQ_ADMIN_PASSWORD`: see above
- `DATABASE_PASSWORD`: only production, database password
- `DEVISE_SECRET_KEY`: only tests, production, devise secret key
- `SECRET_KEY`: only production, secret key base

##### Database configuration
Locate `pg_hba.conf`. On Fedora this is in `/var/lib/pgsql/data/`.
This file tells postgresql how to authenticate users. Read about it on the [PostgreSQL docs][1].
The postgres user you use must be a postgres superuser, as rails needs to enable the uuid extension.
To create a postgres user "gamocosm":

- Switch to the `postgres` user: `(sudo) su - postgres`
- Run `createuser --createdb --pwprompt --superuser gamocosm` (`createuser --help` for more info)

Depending on what method you want to use, add the following under the line that looks like `# TYPE DATABASE USER ADDRESS METHOD`.
By default, `config/database.yml` uses `ENV['USER']` (your OS username) as the database username, for peer identification.
The examples use "gamocosm" as the username; change this to whatever your OS username is.
Alternatively, you can edit `config/database.yml` to use a different user.

- trust
	- Easiest, but least secure. Typically ok on development machines. Blindly trusts the user
	- Add `local all gamocosm trust`
- peer
	- Checks if the postgresql user matches the operating system user
	- Create a postgres user with your OS username (example uses "gamocosm")
	- Add `local all gamocosm peer`. Note: an entry `local all all peer` may already exist, so you won't have to do anything
- md5
	- Client supplies an MD5-encrypted password
	- Add `local all gamocosm md5`

#### Tests
Start Sidekiq: `RAILS_ENV=test ./env.sh sidekiq`
Run `./env.sh rake test` (parallel to Sidekiq).
Will create servers using the Digital Ocean api token from "env.sh".
If nothing fails tests should delete everything they create.

#### Technical details
Hmmmm.

##### Data
Gamocosm has a lot of infrastructure; there's Digital Ocean's API, there're the Digital Ocean servers/droplets, there's Minecraft and its wrapper on the servers, the Gamocosm rails server, and the Gamocosm sidekiq worker.
Avoid state whenever possible. Less data equals less chance of corruption.
Idempotency is good.

##### Error handling

- Methods that "do things" should return nil on success, or a message or object on error.
- Methods that "return things" should use `.error!` to mark a return value is an error. These errors should always be strings.
- You can use `.error?` to check if a return value is an error. `nil` cannot be made an error.
- These methods are defined on `Object` in `config/initializers/error.rb`
- I prefer only throwing exceptions in "exceptional cases", not when I expect something to go wrong (e.g. user input).

##### Important checks
- `server.remote.exists?`: `!server.remote_id.nil?`
- `server.remote.error?`: whether there was an error or not retrieving info about a droplet from Digital Ocean
	- true if the user is missing his Digital Ocean API token, or if it's invalid
	- false if `!server.remote.exists?`
	- don't need to check this before `server.remote` actions (e.g. `server.remote.create`)
- `server.running?`: `server.remote.exists? && !server.remote.error? && server.remote.status == 'active'`
- `user.digital_ocean.nil?`: Digital Ocean API token missing
- `minecraft.node.error?`: error communicating with Minecraft wrapper on server
- `minecraft.running?`: `server.running? && !node.error? && node.pid > 0` (notice symmetry with `server.running?`)

#### Other useful stuff
- Development/test user (from `db/seed.rb`): email "test@test.com", password "1234test", has the Digital Ocean api token from `env.sh`
- The Sidekiq web interface is mounted at `/sidekiq`
- New Relic RPM is available in developer mode at `/newrelic`
- Run the console: `./env.sh rails c`
- Reset the database: `./env.sh rake db:reset`
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console
- The deployment scripts and configuration are in the `sysadmin/` directory
- List of `rake db` commands: [Stack Overflow][3]

### Credits
- Special thanks to [geetfun][2] who helped with the original development

[1]: http://www.postgresql.org/docs/9.3/static/auth-pg-hba-conf.html
[2]: https://github.com/geetfun
[3]: http://stackoverflow.com/questions/10301794/
[4]: https://github.com/Gamocosm/minecraft-server_wrapper
