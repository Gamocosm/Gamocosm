# == Schema Information
#
# Table name: servers
#
#  id                 :uuid             not null, primary key
#  user_id            :integer          not null
#  name               :string(255)      not null
#  created_at         :datetime
#  updated_at         :datetime
#  domain             :string           not null
#  pending_operation  :string
#  ssh_port           :integer          default(4022), not null
#  ssh_keys           :string
#  setup_stage        :integer          default(0), not null
#  remote_id          :integer
#  remote_region_slug :string           not null
#  remote_size_slug   :string           not null
#  remote_snapshot_id :integer
#  timezone_delta     :integer          default(0), not null
#  api_key            :string           not null
#  preserve_snapshot  :boolean          default(FALSE), not null
#

require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  def setup
    @server = Server.first
    @server.update_columns(pending_operation: nil)
  end

  test 'invalid ram' do
    ServerLog.delete_all
    mock_do_base(200)
    old_size = @server.remote_size_slug
    @server.remote_size_slug = 'badness'
    x = @server.ram
    assert_equal 1024, x, 'Server should have selected default 1024MB of RAM'
    assert_equal 1, @server.logs.count, 'Should have 1 log message'
    assert_equal 'Unknown Digital Ocean size slug badness; only starting server with 1 GB of RAM', @server.logs.first.message, 'Should have log message about bad size setting'
    @server.reload
    assert_equal old_size, @server.remote_size_slug, 'Server size slug should not have saved'
  end

  test 'stop already off server' do
    mock_do_droplet_action(1).stub_do_droplet_action(422, 'shutdown').times_only(1)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'snapshot').times_only(1)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(2)
    begin
      @server.update_columns(remote_id: 1)
      x = @server.stop
      assert_nil x
      assert_equal 1, WaitForSnapshottingServerWorker.jobs.count
      WaitForSnapshottingServerWorker.jobs.clear
    ensure
      @server.update_columns(remote_id: nil)
    end
  end

  test 'remote destroy snapshot already deleted' do
    mock_do_image_delete(404, 1, { id: 'not_found' })
    begin
      @server.update_columns(remote_snapshot_id: 1)
      x = @server.remote.destroy_saved_snapshot
      assert_nil x, "Remote destroy saved snapshot should have been ok with already deleted image, was #{x}"
    ensure
      @server.update_columns(remote_snapshot_id: nil)
    end
  end

  test 'parse and save schedule' do
    assert_not @server.parse_and_save_schedule('abc'), 'Server saved schedule text \'abc\'!'
    assert_equal 1, @server.errors.full_messages_for(:schedule_text).count, 'Server schedule should have error for line "abc"'
    @server.errors.clear
    text = [
      'monday 12:00 am start',
      'tuesday 1:00 am start',
      'wednesday 2:00 am start',
    ].join("\n")
    begin
      assert @server.parse_and_save_schedule(text), 'Server should have saved valid schedule text'
      assert @server.errors.empty?, 'Server should have no errors'
      assert_equal 3, @server.scheduled_tasks.count, 'Server should have 3 scheduled tasks'
    ensure
      @server.scheduled_tasks.delete_all
    end
  end
end
