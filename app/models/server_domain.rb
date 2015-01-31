# == Schema Information
#
# Table name: server_domains
#
#  id        :integer          not null, primary key
#  server_id :integer          not null
#  name      :string(255)
#

class ServerDomain < ActiveRecord::Base
  belongs_to :server

  after_initialize :after_initialize_callback

  def after_initialize_callback
    self.name ||= self.random_name
  end

  def random_name
    chars = ('a'..'z').to_a
    return (0...8).map { chars[rand(chars.length)] }.join
  end

end
