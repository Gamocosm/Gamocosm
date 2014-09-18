Gamocosm
========

## Update as of Microsoft buying Mojang
Whelp, well 6+ months of effort possibly down the drain.
This is in limbo until Microsoft's plans for Minecraft are clear... don't even know if they'll allow public servers

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

### Minecraft Server Wrapper
The [Minecraft Server Wrapper][4] (for lack of a better name) is a Python webserver written with Flask.
It provides an HTTP API for starting and stopping Minecraft servers, and a few other misc. actions.
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
1. Run `cp config/app.yml.template config/app.yml`
1. Edit `config/app.yml`
1. Start postgresql, memcached, and redis manually: `(sudo) service start postgresql/memcached/redis`, or enable them to start at boot time: `(sudo) service enable postgresql/memcached/redis`
1. After configuring the database, run `bundle exec rake db:setup`
1. Start the server: `bundle exec rails s`
1. Start the Sidekiq worker: `bundle exec sidekiq`

##### config/app.yml options
This is for Econfig. Values added here are available in ruby from `Gamocosm.foo`.

- `minecraft_jar_default_url`: Minecraft jar for new servers (default: latest version of vanilla Minecraft)
- `minecraft_wrapper_username`: username used for HTTP basic auth when communicating with the Minecraft server wrapper
- `digital_ocean_base_snapshot_id`: Digital Ocean image for new servers (default: Fedora 20 x64)
- `digital_ocean_referral_link`: help pay for server costs?
- `digital_ocean_api_key`: your Digital Ocean api token
- `digital_ocean_ssh_public_key_path`: ssh key to be added to new servers to SSH into
- `digital_ocean_ssh_private_key_path`: see above
- `digital_ocean_ssh_private_key_passphrase`: see above
- `sidekiq_admin_username`: HTTP basic auth for Sidekiq web interface
- `sidekiq_admin_password`: see above

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

#### Technical details
Hmmmm.

##### Data
Gamocosm has a lot of infrastructure; there's Digital Ocean's API, there're the Digital Ocean servers/droplets, there's Minecraft and its wrapper on the servers, the Gamocosm rails server, and the Gamocosm sidekiq worker.
Avoid state whenever possible. Less data equals less chance of corruption.
Idempotency is good.

##### Error handling
Methods that "do things" should return nil on success, or a message or object on error.

Methods that "return things" should use `.error!` to mark a return value is an error.
You can use `.error?` to check if a return value is an error. `nil` cannot be made an error.
These methods are defined on `Object` in `config/initializers/error.rb`
Why don't I use exceptions? Hmmmmm...
I prefer only throwing exceptions in "exceptional cases", not when I know something might be wrong (e.g. user input).
I don't like wrapping everything in try-catches for simple error checking.

#### Other useful stuff
- Development/test user (from `db/seed.rb`): email "test@test.com", password "1234test", has the Digital Ocean api token from `config/app.yml`
- The Sidekiq web interface is mounted at `/sidekiq`
- New Relic RPM is available in developer mode at `/newrelic`
- Run the console: `bundle exec rails c`
- Reset the database: `bundle exec rake db:reset`
- Reset Sidekiq jobs: `Sidekiq::Queue.new.each { |job| job.delete }` in the rails console
- Reset Sidekiq stats: `Sidekiq::Stats.new.reset` in the rails console
- The deployment scripts and configuration are in the `sysadmin/` directory
- List of `rake db` commands: [Stack Overflow][3]

### Credits
- Special thanks to [geetfun][2] who helped with the original development

[1]: http://www.postgresql.org/docs/9.3/static/auth-pg-hba-conf.html
[2]: https://github.com/geetfun
[3]: http://stackoverflow.com/questions/10301794/
[4]: https://github.com/Raekye/minecraft-server_wrapper
