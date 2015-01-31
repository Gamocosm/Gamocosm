Gamocosm [![Build Status](https://travis-ci.org/Gamocosm/Gamocosm.svg?branch=master)](https://travis-ci.org/Gamocosm/Gamocosm)
========

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

### Minecraft Server Wrapper
The [Minecraft Server Wrapper][4] (for lack of a better name) is a light python webserver.
It provides an HTTP API for starting and stopping Minecraft servers, downloading the world, etc.
Please check it out and help improve it too!

### Gamocosm Minecraft Flavours
The [gamocosm-minecraft-flavours][10] repository includes the setup scripts used to install different flavours of Minecraft on a new server.
Read this [wiki page][11] for adding support for new flavours, or manually installing something yourself.

### Contributing
Pull requests are welcome!

#### Tests

- `./env.sh rake test` for everything (uses API token from "env.sh")
- `./env.sh rake test:functionals test:units` for local tests
- If nothing fails tests should delete everything they create.

- Because there's a lot of infrastructure (see below, "Technical details"), sometimes tests will fail for random reasons
- I have not found a good workaround for this
- Run `RAILS_ENV=test ./env.sh rails [s|c]` to run the server or console (respectively) in test mode
- Note: the test server does not automatically reload source files when you edit them. You must restart the server

#### Setting up your development environment
You should have a Unix/Linux system.
The following instructions were made for Fedora 20, but the steps should be similar on other distributions.

1. Install postgresql and development headers and libraries, memcached, redis, and nodejs: `(sudo) yum install postgresql-server postgresql-contrib postgresql-devel memcached redis nodejs`
1. Install Ruby 2.0.0+: `(sudo) yum install ruby`. You can also use RVM
1. Install other things needed for gems: `(sudo) yum install gcc`
1. Install Bundler: `gem install bundler`
1. Install gem dependencies: `bundle install`
1. Run `cp env.sh.template env.sh`
1. Run `chmod u+x env.sh`
1. Enter config in `env.sh`
1. Initialize postgresql: `(sudo) postgresql-setup initdb`
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
- `DATABASE_USER`: hmmmm
- `DATABASE_PASSWORD`: hmmmm
- `DATABASE_HOST`: database host. If specified, Rails will use a TCP connection (e.g. "localhost"). If left blank, Rails will use a local Unix socket connection
- `MEMCACHED_HOST`: hmmmm
- `SIDEKIQ_REDIS_URL`: see [advanced options][5] in the Sidekiq wiki
- `MAIL_SERVER_*`: see [action mailer configuration][6] in the Rails guide
- `USER_SERVERS_DOMAIN`: subdomain for user servers (e.g. `gamocosm.com`)
- `CLOUDFLARE_API_TOKEN`: hmmm
- `CLOUDFLARE_EMAIL`: hmmm
- `DEVISE_SECRET_KEY`: only tests, production
- `SECRET_KEY`: only production
- `DEVELOPER_EMAILS`: comma separated list of emails to send exceptions to
- `BADNESS_SECRET`: secret to protect `/badness` endpoint

##### Database configuration
Locate `pg_hba.conf`. On Fedora this is in `/var/lib/pgsql/data/`.
This file tells postgresql how to authenticate users. Read about it on the [PostgreSQL docs][1].
To restart postgresql: `(sudo) service postgresql restart`
`config/database.yml` gets the database username from the environment variable `DATABASE_USER` (default "gamocosm").
The default value in "env.sh.template" for `DATABASE_HOST` is blank, so if you don't change it Rails will use a local Unix socket connection.
The postgres user you use must be a postgres superuser, as rails needs to enable the uuid extension.
To create a postgres user "gamocosm":

- Switch to the `postgres` user: `(sudo) su - postgres`
- Run `createuser --createdb --pwprompt --superuser gamocosm` (`createuser --help` for more info)

Depending on what method you want to use, add the following under the line that looks like `# TYPE DATABASE USER ADDRESS METHOD`.

- Type
	- `local` (local Unix socket) or `host` (TCP connection)
- Database
	- `postgres,gamocosm_development,gamocosm_test,gamocosm_production`
- User
	- `gamocosm`
- Address
	- Leave blank for `local` type
	- Localhost is `127.0.0.1/32` in ipv4 and `::1/128` in ipv6. My system used ipv6 (postgres did not match the entry when I entered localhost ipv4)
- Method
	- trust
		- Easiest, but least secure. Typically ok on development machines. Blindly trusts the user
	- peer
		- Checks if the postgresql user matches the operating system user
		- Since `config/database.yml` specifies the database user to be "gamocosm", using this method is more troublesome, at least in development, because you have to either change that to your OS username and create a postgresql user with your username, or create a new OS account called "gamocosm" and a postgresql user "gamocosm"
	- ident
		- Same as `peer` but for network connections
	- md5
		- Client supplies an MD5-encrypted password
		- This is the recommended method

Example: `local postgres,gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5`

#### Technical details
Hmmmm.

##### Data
- Gamocosm has a lot of infrastructure: Digital Ocean's API, Digital Ocean servers/droplets, Minecraft and the server wrapper, the Gamocosm rails server, and the Gamocosm sidekiq worker
- Avoid state whenever possible; less chance of corruption with less data
- Idempotency is good

##### Error handling

- Methods that "do things" should return nil on success, or a message or object on error.
- Methods that "return things" should use `.error!` to mark a return value is an error. These errors should always be strings.
- You can use `.error?` to check if a return value is an error. `nil` cannot be made an error.
- These methods are defined on `Object` in `config/initializers/my_extensions.rb`
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

##### Background workers
- Idempotent
- Use `ActiveRecord::Base.connection_pool.with_connection do |conn|` if threads (e.g. teimout) access the database
- Run finite amount of times (keep track of how many times looped)
- Reset the state of the server if anything goes wrong (any exit points)
- Check that the remote exists and is not errored
- Log errors to user minecraft server, include 'Aborting' when not finishing
- 'Aborting' should always be followed by `server.reset_partial` and `return`

#### Other useful stuff
- Development/test user (from `db/seed.rb`): email "test@test.com", password "1234test", has the Digital Ocean api token from `env.sh`
- The Sidekiq web interface is mounted at `/sidekiq`
- Sidekiq doesn't automatically reload source files when you edit them. You must restart it for changes to take effect
- New Relic RPM is available in developer mode at `/newrelic`
- Run the console: `./env.sh rails c`
- Reset the database: `./env.sh rake db:reset`
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console
- The deployment scripts and configuration are in the `sysadmin/` directory
- List of `rake db` commands: [Stack Overflow][3]

### Credits
- Special thanks to [geetfun][2] who helped with the original development
- [SuperMarioBro][7] for helping iron out some initial bugs, adding support for more Minecraft flavours
- [bearbin][8] for helping iron out some initial bugs
- [chiisana][9] for feedback and other ideas, resources
- [KayoticSully][12] for planning and development on the server wrapper API

[1]: http://www.postgresql.org/docs/9.3/static/auth-pg-hba-conf.html
[2]: https://github.com/geetfun
[3]: http://stackoverflow.com/questions/10301794/
[4]: https://github.com/Gamocosm/minecraft-server_wrapper
[5]: https://github.com/mperham/sidekiq/wiki/Advanced-Options
[6]: http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration
[7]: http://www.reddit.com/user/SuperMarioBro
[8]: https://github.com/bearbin
[9]: http://www.reddit.com/user/chiisana
[10]: https://github.com/Gamocosm/gamocosm-minecraft-flavours
[11]: https://github.com/Gamocosm/Gamocosm/wiki/Installing-different-versions-of-Minecraft
[12]: https://github.com/KayoticSully
