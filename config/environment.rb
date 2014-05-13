# Load the Rails application.
require File.expand_path('../application', __FILE__)

env_file = Rails.root.join('.env')
if File.exists? env_file
  env_data = YAML.load_file(env_file)[Rails.env]
  if !env_data.nil?
    env_data.each do |k, v|
      ENV[k.upcase] = v
    end
  end
end

# Initialize the Rails application.
Rails.application.initialize!
