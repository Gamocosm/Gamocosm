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

  # in minutes
  PARTITION_SIZE = 30
  # in minutes, the margin of error
  PARTITION_DELTA = 5

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
    hours = (self.partition / 100) + self.server.timezone_delta
    h_24 = hours % 24
    h_12 = h_24 % 12
    ampm = h_24 < 12 ? 'am' : 'pm'
    d = hours / 24 % 7
    return "#{DAYS_OF_WEEK_INVERSE[d]} #{h_12 == 0 ? 12 : h_12}:#{m.to_s.rjust(2, '0')} #{ampm} #{action}"
  end

  def self.parse(str, server)
    xs = []
    str.each_line do |l|
      x = self.parse_line(l.clean, server)
      if x.error?
        return x
      end
      if !x.nil?
        xs.push(x)
      end
    end
    return xs
  end

  def self.parse_line(line, server)
    if line.nil?
      return nil
    end
    if line =~ /([a-z]+)\s+(\d+):(\d\d)\s*([a-z]+)\s+([a-z]+)/
      day = DAYS_OF_WEEK[$1]
      hour = $2.to_i
      minute = $3.to_i
      ampm = AMPM[$4]
      action = $5
      if day.nil?
        return "Bad day of week \"#{$1}\"".error!(nil)
      end
      if hour <= 0 || hour > 12
        return "Bad hour \"#{$2}\"".error!(nil)
      end
      hour = hour % 12
      if minute < 0 || minute >= 60 || minute % PARTITION_SIZE != 0
        return "Bad minute \"#{$3}\"".error!(nil)
      end
      if ampm.nil?
        return "Bad am/pm \"#{$4}\"".error!(nil)
      end
      if !ACTIONS.include?(action)
        return "Bad action \"#{$5}\"".error!(nil)
      end
      return ScheduledTask.new({
        server: server,
        partition: Partition.calculate(day, hour, minute, ampm, server.timezone_delta),
        action: action,
      })
    end
    return "Bad schedule item format \"#{line}\"".error!(nil)
  end

  def self.server_time_string
    return DateTime.now.in_time_zone(Gamocosm::TIMEZONE).strftime('%-I:%M %P (%H:%M) %Z')
  end

  class Partition
    attr_reader :value
    attr_reader :snap
    attr_reader :next

    def initialize(value)
      @value = value
      raw_snap = (value * 2 + PARTITION_SIZE) / 2 / PARTITION_SIZE * PARTITION_SIZE
      @snap = Partition.fix(raw_snap)

      @is_valid = (@value - raw_snap).abs <= PARTITION_DELTA
      @next = @snap
      if self.valid? || @snap < @value
        @next = Partition.fix(@snap + PARTITION_SIZE)
      end
    end

    def self.calculate(day, hour, minute, ampm, delta)
      x = ((day * 24) + (hour) + (ampm * 12) - (delta)) % (7 * 24)
      return x * 100 + minute
    end

    def valid?
      @is_valid
    end

    # convers 60+ minutes to hour
    def self.fix(x)
      y = x % 100
      return (x / 100 + y / 60) * 100 + y % 60
    end

    # difference in minutes
    def self.diff(x, y)
      return x / 100 * 60 + x % 100 % 60 - (y / 100 * 60 + y % 100 % 60)
    end

    def self.server_current
      return self.from_datetime(DateTime.current)
    end

    def self.from_datetime(x)
      return Partition.new(Partition.calculate((x.wday - 1) % 7, x.hour, x.minute, 0, 0))
    end
  end
end
