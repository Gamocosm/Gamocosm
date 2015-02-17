# == Schema Information
#
# Table name: server_logs
#
#  id         :integer          not null, primary key
#  server_id  :uuid             not null
#  message    :text             not null
#  debuginfo  :string(255)      not null
#  created_at :datetime
#  updated_at :datetime
#

class ServerLog < ActiveRecord::Base
  belongs_to :server

  def when
    return created_at.in_time_zone(ActiveSupport::TimeZone[-8]).strftime('%Y %b %e (%H:%M:%S %Z)')
  end
end
