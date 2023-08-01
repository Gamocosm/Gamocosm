# See:
# - https://puma.io/puma/Puma/DSL.html
# - https://github.com/puma/puma/blob/master/lib/puma/dsl.rb
# - https://github.com/puma/puma/blob/master/lib/puma/configuration.rb
# - `puma --help`

workers 2
preload_app!
