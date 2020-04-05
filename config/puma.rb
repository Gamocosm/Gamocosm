workers 1
threads 0, 8

preload_app!

bind "unix:///#{File.expand_path('../run/puma.sock', __dir__)}"
environment ENV['RAILS_ENV']


