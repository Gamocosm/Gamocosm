workers 1
threads 0, 4

preload_app!

bind Rails.env.production? ? 'unix:///var/run/gamocosm/puma.sock' : 'tcp://0.0.0.0:3000'
environment ENV['RAILS_ENV']


