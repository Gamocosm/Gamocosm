Gamocosm [![Build Status](https://travis-ci.org/Gamocosm/Gamocosm.svg?branch=master)](https://travis-ci.org/Gamocosm/Gamocosm) [![Coverage Status](https://coveralls.io/repos/Gamocosm/Gamocosm/badge.svg)](https://coveralls.io/r/Gamocosm/Gamocosm) [![Gitter chat](https://badges.gitter.im/gamocosm.png)](https://gitter.im/gamocosm/Lobby)
========

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

## Minecraft Server Wrapper
The [Minecraft Server Wrapper][4] (for lack of a better name) is a light python webserver.
It provides an HTTP API for starting and stopping Minecraft servers, downloading the world, etc.
Please check it out and help improve it too!

## Gamocosm Minecraft Flavours
The [gamocosm-minecraft-flavours][10] repository includes the setup scripts used to install different flavours of Minecraft on a new server.
Read this [wiki page][11] for adding support for new flavours, or manually installing something yourself.

## Contributing
Pull requests are welcome!

### Setting up your development environment
You should have a Unix/Linux system.
The following instructions were made for Fedora 20, but the steps should be similar on other distributions.

1. Install postgresql and development headers and libraries, memcached, redis, and nodejs: `(sudo) yum install postgresql-server postgresql-contrib postgresql-devel memcached redis nodejs`
1. Install [RVM][13]. Read the instructions on their page (will be up to date)
1. Install Ruby 2.2.0+: `rvm install 2.2`, and optionally `rvm use --default 2.2`. You may need to install extra packages for compiling ruby (it will tell you)
1. Install other things needed for gems: `(sudo) yum install gcc`
1. Check that `ruby -v` gives you version 2.2. If not, log out and back in (on the computer) to have it reread your `~/.bash_profile`
1. Install Bundler: `gem install bundler`
1. Install gem dependencies: `bundle install`
1. Run `cp env.sh.template env.sh`
1. Enter config in `env.sh`
1. Initialize postgresql: `(sudo) postgresql-setup initdb`
1. Start postgresql, memcached, and redis manually: `(sudo) service start postgresql/memcached/redis`, or enable them to start at boot time: `(sudo) service enable postgresql/memcached/redis`
1. After configuring the database, run `./run.sh rake db:setup`
1. Start the server: `./run.sh rails s`
1. Start the Sidekiq worker: `./run.sh sidekiq`

### Directory hierarchy
- `app`: main source code
- `bin`: rails stuff, don't touch
- `config`: rails app configuration
- `db`: rails app database stuff (schema, migrations, seeds)
- `lib`: rails stuff, don't touch
- `log`: 'nuff said
- `public`: static files
- `server_setup`: stuff for the servers Gamocosm creates (e.g. zram scripts), used by `app/workers/setup_server_worker.rb`
	- see [Additional Info for Server Admins][15] on the wiki for more information
- `sysadmin`: stuff for the Gamocosm server (you can run your own server! this is an open source project)
- `test-docker`: use docker container to test most of `app/workers/setup_server_worker.rb` (more below)
- `test`: pooteeweet
- `vendor`: rails stuff, don't touch

### run.sh and env.sh options
`run.sh` and `tests.sh` both source `env.sh` for environment variables/configuration.
`run.sh` also does `bundle exec` for you, so you just do `./run.sh GEM ARGS ...`.

- `DIGITAL_OCEAN_API_KEY`: your Digital Ocean api token
- `DIGITAL_OCEAN_SSH_PUBLIC_KEY_PATH`: ssh key to be added to new servers to SSH into
- `DIGITAL_OCEAN_SSH_PRIVATE_KEY_PATH`: see above
- `DIGITAL_OCEAN_SSH_PRIVATE_KEY_PASSPHRASE`: see above
- `SIDEKIQ_ADMIN_USERNAME`: HTTP basic auth for Sidekiq web interface
- `SIDEKIQ_ADMIN_PASSWORD`: see above
- `DATABASE_USER`: hmmmm
- `DATABASE_PASSWORD`: hmmmm
- `DATABASE_HOST`: database host. If specified, Rails will use a TCP connection (e.g. "localhost"). If left blank, Rails will use a local Unix socket connection
- `MAIL_SERVER_*`: see [action mailer configuration][6] in the Rails guide
- `USER_SERVERS_DOMAIN`: subdomain for user servers (e.g. `gamocosm.com`)
- `CLOUDFLARE_API_TOKEN`: hmmm
- `CLOUDFLARE_EMAIL`: hmmm
- `CLOUDFLARE_ZONE`: TODO explain how to get this
- `DEVELOPMENT_HOST`: only development, allowed host to access development server
- `DEVISE_SECRET_KEY`: only test, production
- `SECRET_KEY`: only production
- `DEVELOPER_EMAILS`: comma separated list of emails to send exceptions to
- `BADNESS_SECRET`: secret to protect `/badness` endpoint

### Database configuration
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
	- Rails also needs to have access to the `postgres` database (to create new databases?)
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

### Technical details
Hmmmm.

#### Data
- Gamocosm has a lot of infrastructure:
	- CloudFlare DNS API
	- Digital Ocean API
	- Digital Ocean servers/droplets
	- Minecraft and the server wrapper
	- Gamocosm Rails server
	- Gamocosm Sidekiq background workers
- Avoid state and duplicating data (less chance of corruption, logic easier to debug than data)
- Idempotency is good

#### Error handling
- Methods that "do things" should return nil on success, or an object on error
- Methods that "return things" should use `String#error!` to mark a return value is an error
	- This method takes 1 argument: a data object (can be `nil`)
	- e.g. `'API response code not 200'.error!(res)`
	- `String#error!` returns an `Error` object; `Error#to_s` is overridden so the error message can be shown to the user, or the error data (`Error#data`) can be further inspected for handling
- You can use `.error?` to check if a return value is an error. `Error#error?` is overriden to return `true`
- This class and these methods are defined in `config/initializers/monkey_patches.rb`
- Throw exceptions in "exceptional cases", when something is unexpected (e.g. bad user input *is* expected) or can't be handled without "blowing up"

#### Important checks
- `server.remote.exists?`: `!server.remote_id.nil?`
- `server.remote.error?`: whether there was an error or not retrieving info about a droplet from Digital Ocean
	- true if the user is missing his Digital Ocean API token, or if it's invalid
	- false if `!server.remote.exists?`
	- don't need to check this before `server.remote` actions (e.g. `server.remote.create`)
- `server.running?`: `server.remote.exists? && !server.remote.error? && server.remote.status == 'active'`
- `user.digital_ocean.nil?`: Digital Ocean API token missing
- `minecraft.node.error?`: error communicating with Minecraft wrapper on server
- `minecraft.running?`: `server.running? && !node.error? && node.pid > 0` (notice symmetry with `server.running?`)

#### Background workers
- Idempotent
- Keep blocks inside timeouts as simple as possible, cleanup outside of timeout, try to stick to plain old datatypes
	- Use `ActiveRecord::Base.connection_pool.with_connection do |conn|` if threads (e.g. timeout) access the database
- Run finite amount of times (keep track of how many times looped)
- Reset the state of the server if anything goes wrong (any exit points)
- Check that the remote exists and is not errored
- Log errors to user minecraft server, include 'Aborting' when not finishing
- 'Aborting' should always be followed by `server.reset_state` and `return`

#### Other useful stuff
- Development/test user (from `db/seed.rb`): email "test@test.com", password "1234test", has the Digital Ocean api token from `env.sh`
	- the current tests don't use this, and mock all HTTP requests/responses
- The Sidekiq web interface is mounted at `/sidekiq`
- Sidekiq doesn't automatically reload source files when you edit them. You must restart it for changes to take effect
- New Relic RPM is available in developer mode at `/newrelic`
- Run the console: `./run.sh rails c`
- Reset the database: `./run.sh rake db:reset`
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console
- The deployment scripts and configuration are in the `sysadmin/` directory
- List of `rake db` commands: [Stack Overflow][3]

## Tests
- `./run.sh rake test` or `./tests.sh`
- tests use WebMock to mock http requests (no external requests)
- `RAILS_ENV=test ./run.sh rails [s|c]` to run the server or console (respectively) in test mode
- Note: the test server, unlike the dev server, does not automatically reload source files when you change them

### More testing by simulating a user server with Docker
Without a server to connect to, Gamocosm can't try SetupServerWorker or AutoshutdownMinecraftWorker.
"test-docker/" contains a Dockerfile for building a basic Fedora container with an SSH server (simulating a bare Digital Ocean server).
If you set `$TEST_DOCKER` to "true", the tests will assume there is a running Docker Gamocosm container to connect to.

`tests.sh` will build the image, start the container, and delete the container for you if you specify to use Docker.
Otherwise, it will run the tests normally (equivalent to `./run.sh rake test`).
You should have non-root access to Docker.
You could also manage Docker yourself; you can look at the `tests.sh` file for reference.

Example: `TEST_DOCKER=true ./tests.sh`

### Credits
- Special thanks to [geetfun][2] who helped with the original development
- Special thanks to [binary-koan][16] ([Jono Mingard][17]) for designing the new theme! Looks awesome!
- [SuperMarioBro][7] for helping iron out some initial bugs, adding support for more Minecraft flavours
- [bearbin][8] for helping iron out some initial bugs
- [chiisana][9] for feedback and other ideas, resources
- [KayoticSully][12] for planning and development on the server wrapper API
- [Jadorel][14] for feedback and helping iron out some bugs
- [Ajusa][18] for helping with some bugs

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
[13]: https://rvm.io
[14]: https://www.reddit.com/user/Jadorel
[15]: https://github.com/Gamocosm/Gamocosm/wiki/Additional-Info-for-Server-Admins
[16]: https://github.com/binary-koan
[17]: https://mingard.io
[18]: https://github.com/Ajusa
