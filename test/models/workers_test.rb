require 'test_helper'

class WorkersTest < ActiveSupport::TestCase

  def setup
    @server = Server.first
    @server.logs.delete_all
    @server.minecraft.update_columns(autoshutdown_enabled: false)
    @server.update_columns(remote_id: 1, pending_operation: nil, remote_snapshot_id: nil)
  end

  def teardown
    Sidekiq::Worker.clear_all
  end

  test 'record not found in workers' do
    random_uuid = SecureRandom.uuid
    while Server.find_by_id(random_uuid) != nil do
      random_uuid = SecureRandom.uuid
    end
    WaitForStartingServerWorker.perform_in(0.seconds, random_uuid, 0)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have exited after record not found'
    WaitForStoppingServerWorker.perform_in(0.seconds, random_uuid, 0)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have exited after record not found'
    WaitForSnapshottingServerWorker.perform_in(0.seconds, random_uuid, 0)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have exited after record not found'
    SetupServerWorker.perform_in(0.seconds, random_uuid)
    SetupServerWorker.perform_one
    assert_equal 0, SetupServerWorker.jobs.size, 'Worker should have exited after record not found'
    StartMinecraftWorker.perform_in(0.seconds, random_uuid)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have exited after record not found'
    AutoshutdownMinecraftWorker.perform_in(0.seconds, random_uuid)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Worker should have exited after record not found'
  end

  test 'wait for starting server worker too many tries' do
    mock_cf_domain(@server.domain, 64)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(64)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    for i in 0...32
      WaitForStartingServerWorker.perform_one
    end
    assert_equal 1, @server.logs.count, 'Should have one server log'
    WaitForStartingServerWorker.drain
    assert_equal 33, @server.logs.count, 'Should have 33 server logs'
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote doesnt exist' do
    @server.update_columns(remote_id: nil)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error starting server; remote_id is nil/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while starting server/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker event error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error with digital ocean start server action/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote in bad state after event' do
    mock_cf_domain(@server.domain, 64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 1, WaitForStartingServerWorker.jobs.size, 'Worker should have retried'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /finished starting server on digital ocean, but remote status was off.*trying again/i, @server.logs.first.message
  end

  test 'wait for stopping server worker too many tries' do
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(32)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(32)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    for i in 0...16
      WaitForStoppingServerWorker.perform_one
    end
    assert_equal 1, @server.logs.count, 'Should have one server log'
    WaitForStoppingServerWorker.drain
    assert_equal 17, @server.logs.count, 'Should have 16 server logs'
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker action done but not off yet too many tries' do
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(32)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(32)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    for i in 0...16
      WaitForStoppingServerWorker.perform_one
    end
    assert_equal 1, @server.logs.count, 'Should have one server log'
    WaitForStoppingServerWorker.drain
    assert_equal 17, @server.logs.count, 'Should have 16 server logs'
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker remote doesnt exist' do
    @server.update_columns(remote_id: nil)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error stopping server; remote_id is nil/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while stopping server/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker event error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error with digital ocean stop server action/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server snapshot error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_action(1).stub_do_droplet_action(400, 'snapshot')
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error snapshotting server on digital ocean/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker too many tries' do
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(1024)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(256)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    for i in 0...32
      WaitForSnapshottingServerWorker.perform_one
    end
    assert_equal 1, @server.logs.count, 'Should have one server log'
    WaitForSnapshottingServerWorker.drain
    expected_logs = ((256 - 32) / 8) + 1
    assert_equal expected_logs, @server.logs.count, "Should have #{expected_logs} server logs"
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker remote doesnt exist' do
    @server.update_columns(remote_id: nil)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error snapshotting server; remote_id is nil/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while snapshotting server/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker event error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error with digital ocean snapshot server action/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker retrieve snapshots error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active', { snapshot_ids: [] }).times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 1, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have retried'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /finished snapshotting server on digital ocean, but unable to get latest snapshot id. trying again/i, @server.logs.first.message
  end

  test 'wait for snapshotting server worker delete error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_delete(400, 1).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have finished'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error destroying server on digital ocean \(has been snapshotted and saved\)/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server pending operation'
  end

  test 'start minecraft worker remote doesnt exist' do
    @server.update_columns(remote_id: nil)
    StartMinecraftWorker.perform_in(0.seconds, @server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error starting server; remote_id is nil/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'start minecraft worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    StartMinecraftWorker.perform_in(0.seconds, @server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while starting server/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'start minecraft worker node resume error' do
    mock_do_base(200)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_mcsw_start(@server.minecraft).stub_mcsw_start(400, @server.ram)
    mock_do_image_delete(400, 1)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    @server.update_columns(remote_snapshot_id: 1)
    StartMinecraftWorker.perform_in(0.seconds, @server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have finished'
    assert_equal 1, AutoshutdownMinecraftWorker.jobs.size, 'Start Minecraft worker should have queued autoshutdown Minecraft worker'
    AutoshutdownMinecraftWorker.jobs.clear
    @server.reload
    assert_equal 2, @server.logs.count, 'Should have two server logs'
    assert_match /error starting minecraft on server/i, @server.logs.sort.first.message
    assert_match /error deleting saved snapshot on digital ocean after starting server/i, @server.logs.sort.second.message
    assert_not @server.busy?, 'Worker should have reset server pending operation'
  end

  test 'autoshutdown minecraft worker exit conditions' do
    @server.update_columns(remote_id: nil)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @server.logs.count, 'Shouldn\'t have any server logs'

    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    @server.update_columns(remote_id: 1)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @server.logs.count, 'Shouldn\'t have any server logs'

    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    @server.update_columns(pending_operation: 'saving')
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @server.logs.count, 'Shouldn\'t have any server logs'
  end

  test 'autoshutdown minecraft worker remote error' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(400, 'active').times_only(times)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @server.logs.count, "Should have #{times} server logs"
    assert_match /error communicating with digital ocean while checking for autoshutdown/i, @server.logs.first.message, 'Should have server log about error checking remote status'
    assert_nil @server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker node error' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1, { status: 'badness' }).times_only(times)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @server.logs.count, "Should have #{times} server logs"
    assert_match /error getting minecraft pid/i, @server.logs.first.message, 'Should have server log about error getting minecraft pid'
    assert_nil @server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker server not active' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(times)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @server.logs.count, "Should have #{times} server logs"
    assert_match /checking for autoshutdown: remote status was off/i, @server.logs.first.message, 'Should have server log about bad remote status'
    assert_nil @server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker players online' do
    times = @server.minecraft.autoshutdown_minutes * 2
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1).times_only(times)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    with_minecraft_query_server do |mcqs|
      mcqs.num_players = 1
      for _ in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @server.reload
    assert_equal 1, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should still be running'
    assert_equal 0, @server.logs.count, 'Shouldn\'t have any server logs'
    assert_nil @server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
    AutoshutdownMinecraftWorker.clear
  end

  test 'autoshutdown minecraft server error stopping' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_do_droplet_action(1).stub_do_droplet_action(400, 'shutdown').times_only(1)
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1).times_only(times)
    mock_mcsw_stop(200, @server.minecraft).times_only(1)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    with_minecraft_query_server do |mcqs|
      for i in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should be done'
    assert_equal 1, @server.logs.count, 'Should have 1 server log'
    assert_match /in autoshutdown worker, unable to stop server/i, @server.logs.first.message, 'Should have server log about unable to stop server'
    assert_nil @server.pending_operation, "Autoshutdown Minecraft worker should have failed to stop server, but pending operation is #{@server.pending_operation}"
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Wait for stopping server worker should have failed and not queued'
  end

  test 'autoshutdown minecraft worker pid 0' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'shutdown')
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 0).times_only(times)
    mock_mcsw_stop(200, @server.minecraft)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should be done'
    assert_equal 0, @server.logs.count, "Shouldn't have any server logs, but had #{@server.logs.join(',')}"
    assert_equal 'stopping', @server.pending_operation, 'Autoshutdown Minecraft worker should have stopped server'
    assert_equal 1, WaitForStoppingServerWorker.jobs.size, 'Autoshutdown Minecraft worker should have queued wait for stopping server worker'
    WaitForStoppingServerWorker.clear
  end

  test 'autoshutdown minecraft worker error querying' do
    times = @server.minecraft.autoshutdown_minutes + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1).times_only(times)
    @server.minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @server.id)
    with_minecraft_query_server do |mcqs|
      mcqs.drop_packets = true
      for _ in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @server.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @server.logs.count, "Should have #{times} server logs"
    assert_match /could not query minecraft/i, @server.logs.first.message, 'Should have server log about error querying'
    assert_nil @server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'setup server worker add ssh keys' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_ssh_key_show(1).stub_do_ssh_key_show(200, 'a', 'b').times_only(1)
    mock_do_ssh_key_show(2).stub_do_ssh_key_show(400, nil, nil).times_only(1)
    @server.update_columns(ssh_keys: '1,2')
    SetupServerWorker.perform_in(0.seconds, @server.id)
    SetupServerWorker.perform_one
    @server.reload
    assert_equal 0, SetupServerWorker.jobs.size, 'Setup server worker should be done'
    assert_equal 1, @server.logs.count, 'Should have 1 server log'
    assert_match /digital ocean api http response status not ok: 400: /i, @server.logs.first.message, 'Should have server log about error getting SSH key'
    assert_nil @server.ssh_keys, 'Setup server worker should have added and reset ssh keys'
    assert_equal 1, StartMinecraftWorker.jobs.size, 'Setup server worker should have queued Start Minecraft worker'
    StartMinecraftWorker.jobs.clear
  end

  test 'setup server worker remote doesnt exist' do
    @server.update_columns(remote_id: nil)
    SetupServerWorker.perform_in(0.seconds, @server.id)
    SetupServerWorker.perform_one
    assert_equal 0, SetupServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error starting server; remote_id is nil/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'setup server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    SetupServerWorker.perform_in(0.seconds, @server.id)
    SetupServerWorker.perform_one
    assert_equal 0, SetupServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while starting server/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker event failed' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'errored').times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /starting server on digital ocean failed/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker event failed' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'errored').times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /stopping server on digital ocean failed/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker event failed' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'errored').times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @server.reload
    assert_equal 1, @server.logs.count, 'Should have one server log'
    assert_match /snapshotting server on digital ocean failed/i, @server.logs.first.message
    assert_not @server.busy?, 'Worker should have reset server'
  end

  test 'scheduled task worker' do
    patch_schedule_time
    @server.update_columns(remote_id: nil)
    mock_do_ssh_keys_list(200, []).times_only(1)
    mock_do_ssh_key_gamocosm(200)
    mock_do_droplet_create().stub_do_droplet_create(202, @server.name, @server.remote_size_slug, @server.remote_region_slug, Gamocosm::DIGITAL_OCEAN_BASE_IMAGE_SLUG)
    mock_do_droplet_actions_list(200, 1)
    begin
      @server.scheduled_tasks.create!({
        server: @server,
        partition: 0,
        action: 'start'
      })
      ScheduledTaskWorker.perform_in(0.seconds, 0)
      ScheduledTaskWorker.perform_one
      assert_equal 1, ScheduledTaskWorker.jobs.size, 'Scheduled task worker should have completed without exceptions'
      ScheduledTaskWorker.clear
      WaitForStartingServerWorker.clear

      mock_do_droplet_show(1).stub_do_droplet_show(200, 'active')
      mock_do_droplet_action(1).stub_do_droplet_action(200, 'shutdown')
      mock_mcsw_pid(@server.minecraft).stub_mcsw_pid(200, 1).times_only(1)
      mock_mcsw_stop(200, @server.minecraft)
      @server.update_columns(remote_id: 1, pending_operation: nil)
      @server.scheduled_tasks.delete_all
      @server.scheduled_tasks.create!({
        server: @server,
        partition: 0,
        action: 'stop'
      })
      ScheduledTaskWorker.perform_in(0.seconds, 0)
      ScheduledTaskWorker.perform_one
      assert_equal 1, ScheduledTaskWorker.jobs.size, 'Scheduled task worker should have completed without exceptions'
      ScheduledTaskWorker.clear
      WaitForStoppingServerWorker.clear

      # is this necessary?
      @server.reload
      assert_equal 0, @server.logs.count, "Server should have no errors from scheduled task worker, but has #{@server.logs.inspect}"
    ensure
      @server.scheduled_tasks.delete_all
    end
  end
end
