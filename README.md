Gamocosm
========

## Update as of Microsoft buying Mojang
Whelp, well 6+ months of effort possibly down the drain.
This is in limbo until Microsoft's plans for Minecraft are clear... don't even know if they'll allow public servers

Gamocosm makes it easy to run cloud Minecraft servers.
Digital Ocean is used as the backend/hosting service, due to cost, reliability, and accessibility.
Gamocosm works well for friends who play together, but not 24/7.
Running a server 14 hours a week (2 hours every day) may cost 40 cents a month, instead of $5.

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
- `digital_ocean_referral_link`: help pay for server costs :)
- `digital_ocean_api_key`: your Digital Ocean api token
- `digital_ocean_ssh_public_key_path`: ssh key to be added to new servers to SSH into
- `digital_ocean_ssh_private_key_path`: see above
- `digital_ocean_ssh_private_key_passphrase`: see above
- `sidekiq_admin_username`: HTTP basic auth for Sidekiq web interface
- `sidekiq_admin_password`: see above

##### Database configuration
Locate `pg_hba.conf`. On Fedora this is in `/var/lib/pgsql/data/`.
This file tells postgresql how to authenticate users. Read about it on the [PostgreSQL docs][1].

Depending on what method you want to use, add the following under the line that looks like `# TYPE DATABASE USER ADDRESS METHOD`

- trust
	- Easiest, but least secure. Typically ok on development machines. Blindly trusts the user
	- Add `local all gamocosm trust`
- peer
	- Checks if the postgresql user matches the operating system user
	- You will have to change the user in `config/database.yml` to your OS username
	- Add `local all gamocosm peer`. Note: an entry `local all all peer` may already exist, so you won't have to do anything
- md5
	- Client supplies an MD5-encrypted password
	- Switch to the `postgres` user: `(sudo) su - postgres`
	- Create a `gamocosm` user: `createuser --createdb --pwprompt --superuser gamocosm`, `createuser --help` for more info
	- Add `local all gamocosm md5`

You could replace "gamocosm" under the "user" column with "all".

##### Other useful stuff
- Development/test user (from `db/seed.rb`): email "test@test.com", password "1234test", has the Digital Ocean api token from `config/app.yml`
- The Sidekiq web interface is mounted at `/sidekiq`
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
