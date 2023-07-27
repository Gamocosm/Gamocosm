# == Schema Information
#
# Table name: scheduled_tasks
#
#  id        :bigint           not null, primary key
#  server_id :uuid             not null
#  partition :integer          not null
#  action    :string           not null
#

require 'test_helper'

class ScheduledTaskTest < ActiveSupport::TestCase
  setup do
    @server = Server.first
  end

  test 'parse text' do
    text = [
      'mon 12:00 am start',
      'TUESDAY 12:00 PM stop',
      'friday 4:30pm start',
    ].join("\n")
    tasks = ScheduledTask.parse(text, @server)
    text2 = tasks.map { |x| x.to_user_string }
    assert_equal [
      'Monday 12:00 am start',
      'Tuesday 12:00 pm stop',
      'Friday 4:30 pm start',
    ], text2, 'Was not able to parse and reverse schedule text'
  end

  test 'error checking' do
    assert_match /Bad day of week/, ScheduledTask.parse_line('mond 12:00 am start', nil).msg
    assert_match /Bad hour/, ScheduledTask.parse_line('mon 13:00 pm start', nil).msg
    assert_match /Bad minute/, ScheduledTask.parse_line('mon 11:20 pm start', nil).msg
    assert_match /Bad am\/pm/, ScheduledTask.parse_line('mon 12:30 bm start', nil).msg
    assert_match /Bad action/, ScheduledTask.parse_line('mon 12:30 pm hajimemashou', nil).msg
    assert_match /Bad schedule item format/, ScheduledTask.parse_line('abc', nil).msg
  end

  test 'partition calculate, snap, valid, diff, next' do
    a = ScheduledTask::Partition.calculate(0, 1, 5, 1, 20)
    assert_equal (6 * 24 + (24 - 7)) * 100 + 5, a, 'Partition A bad calculation'

    c = ScheduledTask::Partition.calculate(0, 0, 30, 0, 0)
    d = ScheduledTask::Partition.calculate(0, 1, 0, 0, 0)
    e = ScheduledTask::Partition.calculate(0, 1, 30, 0, 0)
    for i in 0...60
      b = ScheduledTask::Partition.new(ScheduledTask::Partition.calculate(0, 0, i, 0, 0))
      if (0 <= i && i <= 5) || (25 <= i && i <= 35) || (55 <= i && i < 60)
        assert b.valid?, "Partition B minute #{i} not valid, but should be #{b.inspect}"
        if i <= 5
          assert_equal c, b.next, "Partition B minute #{i} bad next #{b.inspect}"
        elsif i <= 35
          assert_equal d, b.next, "Partition B minute #{i} bad next #{b.inspect}"
        else
          assert_equal e, b.next, "Partition B minute #{i} bad next #{b.inspect}"
        end
      else
        assert_not b.valid?, "Partition B minute #{i} valid, but should not be #{b.inspect}"
        assert_equal i < 30 ? c : d, b.next, "Partition B minute #{i} bad next #{b.inspect}"
      end
      assert_equal 0, ScheduledTask::Partition.diff(b.next, b.snap) % ScheduledTask::PARTITION_SIZE, "Scheduled task partition diff wrong: #{b.inspect}"
    end
  end
end
