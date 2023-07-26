# == Schema Information
#
# Table name: server_logs
#
#  id         :bigint           not null, primary key
#  server_id  :uuid             not null
#  message    :text             not null
#  debuginfo  :string(255)      not null
#  created_at :datetime
#  updated_at :datetime
#

class ServerLog < ActiveRecord::Base
  belongs_to :server

  def when
    created_at.in_time_zone(Gamocosm::TIME_ZONE).strftime('%Y %b %-d (%H:%M:%S %Z)')
  end

  def to_s
    "{ log #{id}: #{message} }"
  end
end
