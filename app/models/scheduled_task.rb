# == Schema Information
#
# Table name: scheduled_tasks
#
#  id        :integer          not null, primary key
#  server_id :uuid             not null
#  partition :integer          not null
#  action    :string           not null
#

class ScheduledTask < ActiveRecord::Base
  belongs_to :server

  DAYS_OF_WEEK = {
    'mon' => 0,
    'monday' => 0,
    'tue' => 1,
    'tuesday' => 1,
    'wed' => 2,
    'wednesday' => 2,
    'thu' => 3,
    'thursday' => 3,
    'fri' => 4,
    'friday' => 4,
    'sat' => 5,
    'saturday' => 5,
    'sun' => 6,
    'sunday' => 6,
  }
  DAYS_OF_WEEK_INVERSE = Hash[DAYS_OF_WEEK.map { |k, v| [v, k.capitalize] }]

  AMPM = {
    'am' => 0,
    'pm' => 1,
  }

  ACTIONS = [
    'start',
    'stop',
  ]

  def to_user_string
    m = self.partition % 100
    hours = self.partition / 100
    h_24 = hours % 24
    h_12 = h_24 % 12
    ampm = h_24 < 12 ? 'am' : 'pm'
    d = hours / 24
    return "#{DAYS_OF_WEEK_INVERSE[d]} #{h_12}:#{m} #{ampm} #{action}"
  end

  def self.parse(str)
    xs = []
    str.each_line do |l|
      x = self.parse_line(l.clean)
      if !x.nil?
        xs.push(x)
      end
    end
  end

  def self.parse_line(line)
    if line =~ /([a-z]+)\s+(\d+):(\d+)\s*([a-z]+)\s+([a-z]+)/
      day = DAYS_OF_WEEK[$1]
      hour = $2.to_i % 12
      minute = $3.to_i
      ampm = AMPM[$4]
      action = $5
      if day.nil?
        puts("Bad day of week #{$1}\n")
        return nil
      end
      if hour < 0 || hour >= 12
        puts("Bad hour #{$2}")
        return nil
      end
      if minute != 0 && minute != 30
        puts("Bad minute #{$3}")
        return nil
      end
      if ampm.nil?
        puts("Bad am/pm #{$4}")
        return nil
      end
      if !ACTIONS.include?(action)
        puts("Bad action #{$5}")
        return nil
      end
      return ScheduledTask.new({
        partition: self.calculate_partition(day, hour, minute, ampm),
        action: action,
      })
    end
  end

  def self.calculate_partition(day, hour, minute, ampm)
    return (day * 24 + hour + ampm * 12) * 100 + minute
  end
end
