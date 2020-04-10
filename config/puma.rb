workers 1
threads 0, 4

preload_app!

bind 'unix:///var/run/gamocosm/puma.sock'
environment ENV['RAILS_ENV']


