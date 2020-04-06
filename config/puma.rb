workers 1
threads 0, 8

preload_app!

bind 'unix:///var/run/gamocosm/puma.sock'
environment ENV['RAILS_ENV']


