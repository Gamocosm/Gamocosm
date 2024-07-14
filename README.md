Gamocosm [![Build Status](https://circleci.com/gh/Gamocosm/Gamocosm.svg?style=shield)][circleci] [![Coverage Status](https://coveralls.io/repos/github/Gamocosm/Gamocosm/badge.svg?branch=master)][coveralls] [![Gitter Chat](https://badges.gitter.im/gamocosm.png)][gitter]
========

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of \$5.

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
The instructions assume you are executing commands as an unprivileged user;
the sample commands include `sudo` if and only if `root` privileges are necessary.

As of 2022 August 28, deployment and CI have been changed to use containers.
For development, it is also recommended to use containers, but only for the PostgreSQL database and Redis store (as they are "static services").
Note that it is still recommended to run the development Rails server and Sidekiq workers "on the host".
I use [Podman][podman] instead of Docker, but,
at least for these development instructions, they should work by simply replacing `podman` with `docker`.

The steps marked with "directory sensitive" should be run from inside the root of the Gamocosm repository.

#### Configuration
1. Create your environment file:
	`cp template.env gamocosm.env`.
1. Make your environment file readable (and writable) by the file owner (you) only:
	`chown 600 gamocosm.env`.
1. Update the config in `gamocosm.env`.
	See "[Environment File](#environment-file)" below for documentation.
1. Load environment variables:
	`source load_env.sh`.

	You will need to do this in every new shell you run ruby/rails in.

#### Container Setup
1. Install Podman: `sudo dnf install podman`.
1. Ensure that your environment variables have been loaded as above.
1. Create the database container:

	```
	podman create --name gamocosm-database --env "POSTGRES_USER=$DATABASE_USER" --env "POSTGRES_PASSWORD=$DATABASE_PASSWORD" --publish 127.0.0.1:5432:5432 docker.io/postgres:14.5
	```

	You may wish to add the following flag: `--volume gamocosm-database-volume:/var/lib/postgresql/data`;
	[this will prevent Podman from using a randomly-generated name](https://docs.podman.io/en/latest/markdown/podman-create.1.html#volume-v-source-volume-host-dir-container-dir-options),
	which can make debugging or moving things around later easier.
	See [the Docker Hub page for Postgres](https://hub.docker.com/_/postgres/) (scroll down to `PGDATA`) for more information about persistent data with this Postgres image.

1. Create the Redis container:

	```
	podman create --name gamocosm-redis --publish 127.0.0.1:6379:6379 docker.io/redis:7.0.4
	```

	You may wish to add the following flag: `--volume gamocosm-redis-volume:/data`, as above.
	See [the Docker Hub page for Redis](https://hub.docker.com/_/redis/) (scroll down to "start with persistent storage") for more information about persistent data with this Redis image.

1. Start the containers:
	`podman start gamocosm-database gamocosm-redis`.

As is, you'll have to start these containers manually each time you reboot your computer.
You can automate starting Podman containers as "[quadlets](https://www.redhat.com/sysadmin/quadlet-podman)" using systemd.
Example `gamocosm-database.container` and `gamocosm-redis.container` files are provided in Gamocosm's `sysadmin` folder.
Unless you changed the default `DATABASE_USER` from `template.env`, you shouldn't need to edit these files.
If you do need to edit them, systemd supports [drop-in configuration](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html) (search for "drop-in").

```
# Store `DATABASE_PASSWORD` as a Podman secret.
# Make sure you loaded your environment variables as above!
printf "$DATABASE_SECRET" | podman secret create gamocosm-database-password -

# Copy the `.container` files to where systemd expects them.
cp sysadmin/gamocosm-database.container sysadmin/gamocosm-redis.container ~/.config/containers/systemd/

# Tell systemd to detect new files/changes.
systemctl --user daemon-reload

# Start the containers.
systemctl --user start gamocosm-database gamocosm-redis
```

#### Ruby Setup
I recommend using [rbenv][rbenv] to manage Ruby installations.

1. Install dependencies to build Ruby - this depends on your system.
	For a Fedora 36 Server image, the following was sufficient for me:
	`sudo dnf install openssl-devel perl zlib-devel`.
1. Install [rbenv][rbenv] and [ruby-build][ruby-build].
	Read their docs for up to date instructions.
	But, as of 2022 August 28:
	- Run `git clone https://github.com/rbenv/rbenv.git ~/.rbenv`.
	- Add `$HOME/.rbenv/bin` to your `$PATH`, usually done in `~/.bashrc`.

		On recent versions of Fedora, `~/.bashrc` sources any files in the directory `~/.bashrc.d` (if it exists),
		which is more modular than editing `.bashrc` directly.
		It would look something like the following in your `~/.bashrc`.

		```
		# User specific aliases and functions
		if [ -d ~/.bashrc.d ]; then
			for rc in ~/.bashrc.d/*; do
				if [ -f "$rc" ]; then
					. "$rc"
				fi
			done
		fi

		unset rc
		```

		Assuming you have/use this setup, to proceed with the rbenv installation:

		- Create the directory (without failing if it already exists):
			`mkdir -p ~/.bashrc.d`.
		- Create a configuration/initialization file:
			`echo 'PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc.d/rbenv`.
	- Additionally, ensure that rbenv gets autoloaded into any new shells:
		`echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc.d/rbenv` (assuming you're following the modular convention).
	- Restart (close and reopen) your shell for the changes to take effect.
	- Create the plugins directory for rbenv:
		`mkdir ~/.rbenv/plugins`.
	- Get ruby-build:
		`git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build`.
	- Check that ruby-build has been installed correctly:
		`rbenv install --list` (lists stable ruby versions).
1. (directory sensitive) Install Ruby 3.1.2:
	`rbenv install` (it reads `.ruby-version`).
1. (directory sensitive) Check that `ruby -v` gives you version 3.1.2.
1. Install dependencies to build gems:
	`sudo dnf install libpq-devel`.
1. (directory sensitive) Install gem dependencies:
	`bundle install`.

#### Gamocosm Setup
All the commands in this section are "directory sensitive" (should be run in the project root).

1. Generate SSH keys; Gamocosm expects a passphraseless `id_gamocosm` private key in the project root.

	Typically, a passphrase is used to encrypt private keys on the local filesystem, and you would be interactively prompted to provide the passphrase when using the key.
	However, since Gamocosm uses this SSH key "automatically", it can't prompt for a passphrase.
	Gamocosm used to take a passphrase as a configuration option; however, this doesn't actually provide any additional security - the passphrase would be stored (in plain text) on the same filesystem with the same permissions as the private key itself.
	So, now, Gamocosm just expects a passphraseless private key.

	Gamocosm uses SSH to connect to and set up the servers it creates.
	Gamocosm officially only supports `ed25519` keys; somewhere down the stack, `rsa` keys are not supported (`ed25519` keys are considered more secure).
	To generate a new passphraseless key, run: `ssh-keygen -t ed25519 -f id_gamocosm -N ''`.

	You can use this key directly with `ssh -i id_gamocosm` (e.g. if you need to connect to a server directly).
	The files `id_gamocosm` and `id_gamocosm.pub` are ignored in Gamocosm's `.gitignore`,
	so you don't have to worry about accidentally committing them.
1. Setup the database:
	`bundle exec rails db:setup`.
1. Start the server:
	`bundle exec rails s` (defaults to `localhost` in development; use `--binding 0.0.0.0` to listen on all interfaces).
1. Start the Sidekiq worker:
	`bundle exec sidekiq`.
1. (Optional) Open the console:
	`bundle exec rails c`.

_**Note**: most `bundle exec ...` commands will work without `bundle exec` (e.g. just `rails c` or `sidekiq`) -
as long as you don't have other projects using `rbenv`,
and the same version of Ruby (3.1.2),
and the same gem(s),
but different versions of those gems._

### Environment File
- `DATABASE_HOST`:
	May be an absolute path (for a Unix domain socket), or an IP/hostname (for a TCP connection) ([PostgreSQL docs][postgresql-docs-host]).
	When using containers as described above, the default value of `localhost` in `template.env` corresponds to the `127.0.0.1` passed to `--publish` in `podman create`.
- `DATABASE_PORT`:
	Required even for Unix domain sockets.
	The default should work provided you didn't change the PostgreSQL settings.
- `DATABASE_USER`:
	Hmmmm.
- `DATABASE_PASSWORD`:
	Hmmmm.
- `DIGITAL_OCEAN_API_KEY`:
	Your Digital Ocean API token.
	This key is added to the dummy user in development (see [`db/seeds.rb`][db-seeds]) - it's probably convenient for it to have write access.
	For the test environment, it can be anything (but still needs to be set) -
	Gamocosm tests "mock" HTTP requests so it won't actually contact Digital Ocean.
	For production, this key can be read only - it is (just) used to list regions and droplet sizes.
- `REDIS_HOST`:
	When using containers as described above, the default value of `localhost` in `template.env` corresponds to the `127.0.0.1` passed to `--publish` in `podman create`.
- `REDIS_PORT`:
	You can leave this as the default.
- `MAIL_SERVER_*`:
	See [action mailer configuration][rails-action-mailer] in the Rails guide.
- `SECRET_KEY_BASE`:
	Only production.
- `SIDEKIQ_USERNAME`:
	Only production - HTTP basic auth for Sidekiq web interface.
- `SIDEKIQ_PASSWORD`:
	See previous.
- `DEVELOPER_EMAILS`:
	Comma separated list of emails to send exceptions to.
- `BADNESS_SECRET`:
	Secret to test `/badness` endpoint.

## Testing
- `bundle exec rails test` runs the test suite.
	[The CI runs the tests just like this][circleci-config].
	For more options, see [Rails documentation for the test runner][rails-test-runner].
	- Run a specific file: `bundle exec rails test path/to/file.rb`
	- Run a specific test (by line number): `bundle exec rails test path/to/file.rb:123`
	- Run a specific test (by name): `bundle exec rails test path/to/file.rb --name my_test`
- In the test environment, Gamocosm doesn't actually make external HTTP requests; it mocks the requests and responses using [WebMock][webmock].
	So, you don't need a Digital Ocean account or valid API key to run the tests.
- Unfortunately, not all the tests are idempotent; one failing test may leave data in the database that causes subsequent tests to fail.
	You can pass `--fail-fast` to the test runner to stop at the first failing test.
- `RAILS_ENV=test bundle exec rails <s|c>` to run the server or console (respectively) to inspect the test environment.
	- _Note: in the test environment, unlike development, the server does not automatically reload source files when you change them._

### Simulating a User Server with Containers
In the test environment, Gamocosm doesn't make external HTTP requests; it mocks the API responses from Digital Ocean.
Without a server to connect to, Gamocosm can't run `SetupServerWorker` or `AutoshutdownMinecraftWorker`.

The script `test_with_container.sh` runs a container (based on an image built from `tests.Containerfile`)
that simulates a newly created server on Digital Ocean.
Arguments to this script are passed along to `rails test`.

The script takes care of building the image, starting the container, running the tests, and cleaning up the container.

This script has only been tested with Podman on Fedora; I'm not sure if it works with Docker on Ubuntu systems.

## Technical Details
Hmmmm.

### Directory Hierarchy
- [Documentation for Rails directories][rails-directory-hierarchy].
- `sysadmin`: stuff for the Gamocosm server (you can run your own server! This is a true open source project).

### Data
- Gamocosm has a lot of infrastructure:
	- Digital Ocean API
	- Digital Ocean servers/droplets
	- Minecraft and the server wrapper
	- Gamocosm Rails server
	- Gamocosm Sidekiq background workers
- Avoid state and duplicating data (less chance of corruption, logic easier to debug than data)
- Idempotency is good

### Error Handling
- Methods that "do things" should return nil on success, or an object on error
- Methods that "return things" should use `String#error!` to mark a return value is an error
	- This method takes 1 argument: a data object (can be `nil`)
	- e.g. `'API response code not 200'.error!(res)`
	- `String#error!` returns an `Error` object; `Error#to_s` is overridden so the error message can be shown to the user, or the error data (`Error#data`) can be further inspected for handling
- You can use `.error?` to check if a return value is an error. `Error#error?` is overriden to return `true`
- This class and these methods are defined in `config/monkey_patches.rb`
- Throw exceptions in "exceptional cases", when something is unexpected (e.g. bad user input _is_ expected) or can't be handled without "blowing up"

### Important Checks
- `server.remote.exists?`: `!server.remote_id.nil?`
- `server.remote.error?`: whether there was an error or not retrieving info about a droplet from Digital Ocean
	- true if the user is missing his Digital Ocean API token, or if it's invalid
	- false if `!server.remote.exists?`
	- don't need to check this before `server.remote` actions (e.g. `server.remote.create`)
- `server.running?`: `server.remote.exists? && !server.remote.error? && server.remote.status == 'active'`
- `user.digital_ocean.nil?`: Digital Ocean API token missing
- `minecraft.node.error?`: error communicating with Minecraft wrapper on server
- `minecraft.running?`: `server.running? && !node.error? && node.pid > 0` (notice symmetry with `server.running?`)

### Background Workers
- Idempotent
- Keep blocks inside timeouts as simple as possible, cleanup outside of timeout, try to stick to plain old datatypes
	- Use `ActiveRecord::Base.connection_pool.with_connection do |conn|` if threads (e.g. timeout) access the database
- Run finite amount of times (keep track of how many times looped)
- Reset the state of the server if anything goes wrong (any exit points)
- Check that the remote exists and is not errored
- Log errors to user minecraft server, include 'Aborting' when not finishing
- 'Aborting' should always be followed by `server.reset_state` and `return`

### Other Useful Stuff
- Development user (created by [`db/seeds.rb`][db-seeds]) has the Digital Ocean api token from `env.sh`.
- The Sidekiq web interface is mounted at `/sidekiq`.
- Sidekiq doesn't automatically reload source files when you edit them. You must restart it for changes to take effect.
- Run the console: `bundle exec rails c`.
- Reset the database: `bundle exec rake db:reset`.
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console.
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console.
- Start `ScheduledTaskWorker`: `ScheduledTaskWorker.perform_in(0.seconds, 0)` - it will automatically reschedule itself for the next interval.
- The deployment scripts and configuration are in the `sysadmin/` directory.
- List of `rake db` commands: [Stack Overflow][rake-db-commands].
- [Rails extensions to common classes][rails-active-support-extensions].
- [Rails configuration][rails-configuration].

## Credits
- Special thanks to [geetfun][geetfun] who helped with the original development
- Special thanks to [binary-koan][binary-koan] ([Jono Mingard][jono-mingard]) for designing the new theme! Looks awesome!
- [SuperMarioBro][super-mario-bro] for helping iron out some initial bugs, adding support for more Minecraft flavours
- [bearbin][bearbin] for helping iron out some initial bugs
- [chiisana][chiisana] for feedback and other ideas, resources
- [KayoticSully][kayotic-sully] for planning and development on the server wrapper API
- [Jadorel][jadorel] for feedback and helping iron out some bugs
- [Ajusa][ajusa] for helping with some bugs

## Appendix
### Notes
- If `podman build` gets interrupted, you may be left with dangling images: [relevant GitHub issue][podman-dangling-images].
	The solution is to run `buildah rm --all`
	(may need to be installed separately, e.g. `sudo dnf install buildah`)
	(followed by `podman image prune`).

### Database Configuration
**Database configuration is greatly simplified if you use a container image as described above.
However, the following information remains for reference, if you want to run PostgreSQL directly on your system.**

Locate your PostgreSQL data directory.
On Fedora this is `/var/lib/pgsql/data/`.

#### Connection
Locate `postgresql.conf` in your PostgreSQL data directory.
The convention is that commented out settings represent the default values.
For a Unix domain socket connection, `DATABASE_HOST` should be one of the values of `unix_socket_directories`.
In general, the default is `/tmp`.
On Fedora, the default includes both `/tmp` and `/var/run/postgresql`.
For a TCP connection, `DATABASE_HOST` should be one of the values of `listen_addresses` (default `localhost`).
The value `localhost` should work if you're running PostgreSQL locally.
Your `DATABASE_PORT` should be the value of `port` in this file (default `5432`).

You can read more about connecting to PostgreSQL at [PostgreSQL's docs][postgresql-docs-connecting].

#### Authentication
Locate `pg_hba.conf` in your PostgreSQL data directory.
This file tells PostgreSQL how to authenticate users.
Read about it on the [PostgreSQL docs][postgresql-docs-pg-hba].
The Rails config `config/database.yml` reads from the environment variables which you should have set in and loaded from `gamocosm.env` via `source load_env.sh`.

_**Note**: in the past, the database user needed to be a [PostgreSQL superuser][postgresql-docs-roles] to enable the [uuid extension][postgresql-docs-uuid].
However, as of PostgreSQL 13, it seems that it should nolonger be necessary?_

> This module is considered “trusted”, that is, it can be installed by non-superusers who have CREATE privilege on the current database.

To create a PostgreSQL user `gamocosm`:

- Switch to the `postgres` user (on the OS): `sudo su --login postgres`.
- Run `createuser --createdb --pwprompt --superuser gamocosm` (`createuser --help` for more info).

Depending on what method you want to use, in `pg_hba.conf`,
add the following under the line that looks like `# TYPE DATABASE USER ADDRESS METHOD`.

- Type
	- `local` (Unix domain socket) or `host` (TCP connection)
- Database
	- Rails also needs to have access to the `postgres` database (to create new databases?)
	- `postgres,gamocosm_development,gamocosm_test,gamocosm_production`
- User
	- `gamocosm`
- Address
	- Leave blank for `local` type
	- `localhost` is `127.0.0.1/32` in ipv4 and `::1/128` in ipv6.
		My system used ipv6 (PostgreSQL did not match the entry when I entered `localhost`).
- Method
	- `trust`
		- Easiest, but least secure. Typically ok on development machines. Blindly trusts the user.
	- `peer`
		- Checks if the PostgreSQL user matches the operating system user.
		- Since `config/database.yml` specifies the database user to be `gamocosm`,
			it would only work if you developed on an OS account named `gamocosm` as well.
	- `ident`
		- Same as `peer` but for network connections, using the [Ident protocol][wikipedia-ident-protocol]
			(I once tried to get this protocol working and it made no sense to me).
	- md5
		- Client supplies an MD5-encrypted password.
		- This is the recommended method.

Example: `local postgres,gamocosm_development,gamocosm_test,gamocosm_production gamocosm md5`.
You will have to restart PostgreSQL (`sudo systemctl restart postgresql`) for the changes to take effect.

[circleci]: https://circleci.com/gh/Gamocosm/Gamocosm
[coveralls]: https://coveralls.io/github/Gamocosm/Gamocosm?branch=master
[gitter]: https://gitter.im/gamocosm/Lobby

[wiki]: https://github.com/Gamocosm/Gamocosm/wiki
[mcsw]: https://github.com/Gamocosm/minecraft-server_wrapper
[minecraft-flavours]: https://github.com/Gamocosm/gamocosm-minecraft-flavours
[wiki-different-versions]: https://github.com/Gamocosm/Gamocosm/wiki/Installing-Different-Versions-of-Minecraft
[db-seeds]: https://github.com/Gamocosm/Gamocosm/blob/master/db/seeds.rb
[circleci-config]: https://github.com/Gamocosm/Gamocosm/blob/master/.circleci/config.yml

[rbenv]: https://github.com/rbenv/rbenv
[ruby-build]: https://github.com/rbenv/ruby-build

[podman]: https://podman.io/

[postgresql-docs-host]: https://www.postgresql.org/docs/14/libpq-connect.html#LIBPQ-CONNECT-HOST
[postgresql-docs-connecting]: https://www.postgresql.org/docs/14/runtime-config-connection.html
[postgresql-docs-pg-hba]: https://www.postgresql.org/docs/14/auth-pg-hba-conf.html
[postgresql-docs-roles]: https://www.postgresql.org/docs/14/role-attributes.html
[postgresql-docs-uuid]: https://www.postgresql.org/docs/14/uuid-ossp.html
[wikipedia-ident-protocol]: https://en.wikipedia.org/wiki/Ident_protocol

[webmock]: https://github.com/bblimke/webmock

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
[podman-dangling-images]: https://github.com/containers/podman/issues/7889
[rails-test-runner]: https://guides.rubyonrails.org/testing.html#the-rails-test-runner
[rails-directory-hierarchy]: https://guides.rubyonrails.org/getting_started.html#creating-the-blog-application
[rails-active-support-extensions]: https://guides.rubyonrails.org/active_support_core_extensions.html
[rails-configuration]: https://guides.rubyonrails.org/configuring.html
