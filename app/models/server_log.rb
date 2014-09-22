# == Schema Information
#
# Table name: server_logs
#
#  id           :integer          not null, primary key
#  minecraft_id :uuid             not null
#  message      :string(255)      not null
#  debuginfo    :string(255)      not null
#  created_at   :datetime
#  updated_at   :datetime
#

class ServerLog < ActiveRecord::Base
  belongs_to :minecraft

  def when
    return created_at.strftime('%Y %b %e (%l:%H:%S)')
  end
end
