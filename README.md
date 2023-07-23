Gamocosm [![Build Status](https://circleci.com/gh/Gamocosm/Gamocosm.svg?style=shield)][circleci] [![Coverage Status](https://coveralls.io/repos/github/Gamocosm/Gamocosm/badge.svg?branch=master)][coveralls] [![Gitter Chat](https://badges.gitter.im/gamocosm.png)][gitter]
========

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

**This README is directed towards developers; if you are a user looking for more information, please check out the [wiki][wiki] or drop by [Gitter chat][gitter].**

## Minecraft Server Wrapper
The [Minecraft Server Wrapper][mcsw] (for lack of a better name) is a light python webserver.
It provides an HTTP API for starting and stopping Minecraft servers, downloading the world, etc.
Please check it out and help improve it too!

## Gamocosm Minecraft Flavours
The [gamocosm-minecraft-flavours][minecraft-flavours] repository includes the setup scripts used to install different flavours of Minecraft on a new server.
Read this [wiki page][wiki-different-versions] for adding support for new flavours, or manually installing something yourself.

## Contributing
Pull requests are welcome!

### Setting Up Your Development Environment
You should have a Unix/Linux system.
The following instructions were made for Fedora 36 Server, but the steps should be similar on other distributions.
As of 2022 August 28, deployment and CI have been changed to use containers.
For development, containers are more convenient for the PostgreSQL and Redis processes (as they are simply processes/services that aren't "changing"),
but it is still recommended to run the development Rails and Sidekiq server "locally".

1. Install dependencies to build Ruby - this depends on your system.
	For a Fedora 36 Server image, the following was sufficient for me: `(sudo) dnf install openssl-devel perl zlib-devel`.
1. Install [rbenv][rbenv] and [ruby-build][ruby-build]. Read their docs for up to date instructions. But as of 2022 August 28:
	- Run `git clone https://github.com/rbenv/rbenv.git ~/.rbenv`.
	- Add `$HOME/.rbenv/bin` to your `$PATH`, usually done in `~/.bashrc`.

		On recent versions of Fedora, `~/.bashrc` sources any files in the directory `~/.bashrc.d` (if it exists), so you don't have to edit `.bashrc` directly.
		(To create the directory, run `mkdir ~/.bashrc.d`.)
		For example, run ` echo 'PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc.d/rbenv` (you can replace `~/.bashrc.d/rbenv` with `~/.bashrc` to modify `.bashrc` directly).
	- Additionally, add `eval "$(rbenv init - bash)"` to your shell: `echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc.d/rbenv` (again, you may choose to modify `.bashrc` directly).
	- Restart (close and reopen) your shell for the changes to take effect.
	- Create the plugins directory for rbenv: `mkdir ~/.rbenv/plugins`.
	- Get ruby-build: `git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build`.
	- Check that ruby-build has been installed correctly: `rbenv install --list`.
1. Install Ruby 3.1.2: `rbenv install` inside this project root directory (it reads `.ruby-version`).
1. Check that `ruby -v` inside this project gives you version 3.1.2.
1. Install dependencies to build gems: `(sudo) dnf install libpq-devel`.
1. Install gem dependencies: `bundle install`.
1. Generate SSH keys; Gamocosm expects a passphraseless `id_gamocosm` private key in the project root.

	Typically, a passphrase is used to encrypt private keys on the local filesystem, and you would be interactively prompted to provide the passphrase when using the key.
	However, since Gamocosm uses this SSH key "automatically", it can't prompt for a passphrase.
	Gamocosm used to take a passphrase as a configuration option; however, this doesn't actually provide any additional security - the passphrase would be stored (in plain text) on the same filesystem with the same permissions as the private key itself.
	So, now, Gamocosm just expects a passphraseless private key.

	Gamocosm uses SSH to connect to and set up the servers it creates.
	Gamocosm officially only supports `ed25519` keys; somewhere down the stack, `rsa` keys are not supported (`ed25519` keys are considered more secure).
	To generate a new passphraseless key, run: `ssh-keygen -t ed25519 -f id_gamocosm -N ''`.

	You can use this key directly with `ssh -i id_gamocosm` (e.g. if you need to connect to a server directly).
	The file `id_gamocosm` is ignored in Gamocosm's `.gitignore` so you don't have to worry about accidentally committing it.
1. Create your environment file: `cp template.env gamocosm.env`.
1. Make your environment file only readable (and writable) by the file owner (you): `chown 600 gamocosm.env`
1. Update the config in `gamocosm.env`. See below for documentation.
1. Load environment variables: `source load_env.sh`. You will also need to do this in every new shell you run ruby/rails in.
1. Install `podman` (or `docker`): `(sudo) dnf install podman`.
1. Create the database container: `podman create --name gamocosm-database --env "POSTGRES_USER=$DATABASE_USER" --env "POSTGRES_PASSWORD=$DATABASE_PASSWORD" --publish 127.0.0.1:5432:5432 docker.io/postgres:14.5`.
1. Create the Redis container for Sidekiq: `podman create --name gamocosm-sidekiq-redis --publish 127.0.0.1:6379:6379 docker.io/redis:7.0.4`.
1. Start the containers: `podman start gamocosm-database gamocosm-sidekiq-redis`.
1. Setup the database: `bundle exec rails db:setup`.
1. Start the server: `bundle exec rails s` (defaults to `localhost` in development; use `--binding 0.0.0.0` to listen on all interfaces).
1. Start the Sidekiq worker: `bundle exec sidekiq`.
1. Optional: open the console: `bundle exec rails c`.

### Environment File
- `DATABASE_HOST`:
	May be a directory (for a Unix domain socket), or an IP/hostname (for a TCP connection). See below for more information.
	When using containers as described above, the default value of `localhost` corresponds to the `127.0.0.1` passed to `--publish`.
- `DATABASE_PORT`:
	Required even for Unix domain sockets. The default should work provided you didn't change the postgresql settings.
- `DATABASE_USER`:
	Hmmmm.
- `DATABASE_PASSWORD`:
	Hmmmm.
- `DIGITAL_OCEAN_API_KEY`:
	Your Digital Ocean API token.
	This key is added to the dummy user in development (see [`db/seeds.rb`][db-seeds]) - it's probably convenient for it to have write access.
	For the test environment, it can be anything (but still needs to be set) - Gamocosm tests "mock" HTTP requests so it won't actually contact Digital Ocean.
	For production, this key can be read only - it is (just) used to list regions and droplet sizes.
- `REDIS_HOST`:
	When using containers as described above, the default value of `localhost` corresponds to the `127.0.0.1` passed to `--publish`.
- `REDIS_PORT`: You can leave this as the default.
- `SIDEKIQ_ADMIN_USERNAME`: HTTP basic auth for Sidekiq web interface.
- `SIDEKIQ_ADMIN_PASSWORD`: See previous.
- `DEVISE_SECRET_KEY`: Only production.
- `MAIL_SERVER_*`: See [action mailer configuration][rails-action-mailer] in the Rails guide.
- `SECRET_KEY_BASE`: Only production.
- `DEVELOPER_EMAILS`: Comma separated list of emails to send exceptions to.
- `BADNESS_SECRET`: Secret to protect `/badness` endpoint.

### Database configuration
**Database configuration is greatly simplified if you use a container image as described above.
However, the following information remains for reference, if you want to run PostgreSQL directly on your system.**

Locate your postgres data directory.
On Fedora this is `/var/lib/pgsql/data/`.

#### Connection
Locate `postgresql.conf` in your postgres data directory.
The convention is that commented out settings represent the default values.
For a Unix domain socket connection, `DATABASE_HOST` should be one of the values of `unix_socket_directories`.
In general, the default is `/tmp`.
On Fedora, the default includes both `/tmp` and `/var/run/postgresql`.
For a TCP connection, `DATABASE_HOST` should be one of the values of `listen_addresses` (default `localhost`).
The value `localhost` should work if you're running postgresql locally.
Your `DATABASE_PORT` should be the value of `port` in this file (default `5432`).

You can read more about connecting to postgresql at [PostgreSQL's docs][postgresql-docs-connecting].

#### Authentication
Locate `pg_hba.conf` in your postgres data directory.
This file tells postgresql how to authenticate users. Read about it on the [PostgreSQL docs][postgresql-docs-pg-hba].
The Rails config `config/database.yml` reads from the environment variables which you should have set in and loaded from `gamocosm.env` via `source load_env.sh`.
The postgres user you use must be a postgres superuser, as rails needs to enable the uuid extension.
To create a postgres user "gamocosm":

- Switch to the `postgres` user: `(sudo) su --login postgres`.
- Run `createuser --createdb --pwprompt --superuser gamocosm` (`createuser --help` for more info).

Depending on what method you want to use, in `pg_hba.conf` add the following under the line that looks like `# TYPE DATABASE USER ADDRESS METHOD`.

- Type
	- `local` (Unix domain socket) or `host` (TCP connection)
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

Example: `local postgres,gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5`.
You will have to restart postgresql (`(sudo) systemctl restart postgresql`) for the changes to take effect.

### Directory hierarchy
- `app`: main source code
- `bin`: rails stuff, don't touch
- `config`: rails app configuration
- `db`: rails app database stuff (schema, migrations, seeds)
- `lib`: rails stuff, don't touch
- `log`: 'nuff said
- `public`: static files
- `sysadmin`: stuff for the Gamocosm server (you can run your own server! This is a true open source project)
- `test-docker`: use docker container to test most of `app/workers/setup_server_worker.rb` (more below)
- `test`: pooteeweet
- `vendor`: rails stuff, don't touch

### Technical details
Hmmmm.

#### Data
- Gamocosm has a lot of infrastructure:
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
- Throw exceptions in "exceptional cases", when something is unexpected (e.g. bad user input _is_ expected) or can't be handled without "blowing up"

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
- Run the console: `bundle exec rails c`
- Reset the database: `bundle exec rake db:reset`
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console
- The deployment scripts and configuration are in the `sysadmin/` directory
- List of `rake db` commands: [Stack Overflow][rake-db-commands]

## Tests
- `bundle exec rails test`
- tests use WebMock to mock http requests (no external requests)
- `RAILS_ENV=test bundle exec rails <s|c>` to run the server or console (respectively) in test mode
- Note: the test server, unlike the dev server, does not automatically reload source files when you change them

### More testing by simulating a user server with Docker
_**Note**: this section is out of date._

Without a server to connect to, Gamocosm can't try SetupServerWorker or AutoshutdownMinecraftWorker.
"test-docker/" contains a Dockerfile for building a basic Fedora container with an SSH server (simulating a bare Digital Ocean server).
If you set `$TEST_DOCKER` to "true", the tests will assume there is a running Docker Gamocosm container to connect to.

`tests.sh` will build the image, start the container, and delete the container for you if you specify to use Docker.
Otherwise, it will run the tests normally (equivalent to `bundle exec rails test`).
You should have non-root access to Docker.
You could also manage Docker yourself; you can look at the `tests.sh` file for reference.

Example: `TEST_DOCKER=true ./tests.sh`

### Credits
- Special thanks to [geetfun][geetfun] who helped with the original development
- Special thanks to [binary-koan][binary-koan] ([Jono Mingard][jono-mingard]) for designing the new theme! Looks awesome!
- [SuperMarioBro][super-mario-bro] for helping iron out some initial bugs, adding support for more Minecraft flavours
- [bearbin][bearbin] for helping iron out some initial bugs
- [chiisana][chiisana] for feedback and other ideas, resources
- [KayoticSully][kayotic-sully] for planning and development on the server wrapper API
- [Jadorel][jadorel] for feedback and helping iron out some bugs
- [Ajusa][ajusa] for helping with some bugs

[circleci]: https://circleci.com/gh/Gamocosm/Gamocosm
[coveralls]: https://coveralls.io/github/Gamocosm/Gamocosm?branch=master
[gitter]: https://gitter.im/gamocosm/Lobby

[wiki]: https://github.com/Gamocosm/Gamocosm/wiki
[mcsw]: https://github.com/Gamocosm/minecraft-server_wrapper
[minecraft-flavours]: https://github.com/Gamocosm/gamocosm-minecraft-flavours
[wiki-different-versions]: https://github.com/Gamocosm/Gamocosm/wiki/Installing-different-versions-of-Minecraft
[db-seeds]: https://github.com/Gamocosm/Gamocosm/blob/master/db/seeds.rb

[rbenv]: https://github.com/rbenv/rbenv
[ruby-build]: https://github.com/rbenv/ruby-build

[postgresql-docs-connecting]: https://www.postgresql.org/docs/14/runtime-config-connection.html
[postgresql-docs-pg-hba]: https://www.postgresql.org/docs/14/auth-pg-hba-conf.html

[geetfun]: https://github.com/geetfun
[binary-koan]: https://github.com/binary-koan
[jono-mingard]: https://mingard.link
[super-mario-bro]: http://www.reddit.com/user/SuperMarioBro
[bearbin]: https://github.com/bearbin
[chiisana]: http://www.reddit.com/user/chiisana
[kayotic-sully]: https://github.com/KayoticSully
[jadorel]: https://www.reddit.com/user/Jadorel
[ajusa]: https://github.com/Ajusa

[rake-db-commands]: http://stackoverflow.com/questions/10301794/
[rails-action-mailer]: http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration
