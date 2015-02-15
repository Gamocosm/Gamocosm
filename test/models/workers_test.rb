require 'test_helper'

class WorkersTest < ActiveSupport::TestCase

  def setup
    @minecraft = Minecraft.first
    @minecraft.logs.delete_all
    @minecraft.update_columns(autoshutdown_enabled: false)
    @minecraft.server.update_columns(remote_id: 1, pending_operation: nil)
  end

  def teardown
  end

  test 'record not found in workers' do
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, 0, 0)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have exited after record not found'
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, 0, 0)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have exited after record not found'
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, 0, 0)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have exited after record not found'
    SetupServerWorker.perform_in(0.seconds, @minecraft.user_id, 0)
    SetupServerWorker.perform_one
    assert_equal 0, SetupServerWorker.jobs.size, 'Worker should have exited after record not found'
    StartMinecraftWorker.perform_in(0.seconds, 0, )
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have exited after record not found'
    AutoshutdownMinecraftWorker.perform_in(0.seconds, SecureRandom.uuid)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Worker should have exited after record not found'
  end

  test 'wait for starting server worker too many tries' do
    @minecraft.server.create_server_domain
    mock_cf_domain(@minecraft.server.server_domain.name, 64)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(64)
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    for i in 0...32
      WaitForStartingServerWorker.perform_one
    end
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    WaitForStartingServerWorker.drain
    assert_equal 33, @minecraft.logs.count, 'Should have 32 server logs'
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote doesn\'t exist' do
    @minecraft.server.update_columns(remote_id: nil)
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error starting server; remote_id is nil/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote error' do
    @minecraft.server.create_server_domain
    mock_cf_domain(@minecraft.server.server_domain.name, 64)
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while starting server/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker event error' do
    @minecraft.server.create_server_domain
    mock_cf_domain(@minecraft.server.server_domain.name, 64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error with digital ocean start server action/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for starting server worker remote in bad state after event' do
    @minecraft.server.create_server_domain
    mock_cf_domain(@minecraft.server.server_domain.name, 64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    WaitForStartingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStartingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /finished starting server on digital ocean, but remote status was off/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker too many tries' do
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(32)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(32)
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    for i in 0...16
      WaitForStoppingServerWorker.perform_one
    end
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    WaitForStoppingServerWorker.drain
    assert_equal 17, @minecraft.logs.count, 'Should have 16 server logs'
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker remote doesn\'t exist' do
    @minecraft.server.update_columns(remote_id: nil)
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error stopping server; remote_id is nil/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStartingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while stopping server/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker event error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error with digital ocean stop server action/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server worker remote in bad state after event' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /finished stopping server on digital ocean, but remote status was active/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for stopping server snapshot error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_action(1).stub_do_droplet_action(400, 'snapshot')
    WaitForStoppingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForStoppingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error snapshotting server on digital ocean/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker too many tries' do
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'in-progress').times_only(64)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(64)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    for i in 0...32
      WaitForSnapshottingServerWorker.perform_one
    end
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    WaitForSnapshottingServerWorker.drain
    assert_equal 33, @minecraft.logs.count, 'Should have 32 server logs'
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker remote doesn\'t exist' do
    @minecraft.server.update_columns(remote_id: nil)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error snapshotting server; remote_id is nil/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while snapshotting server/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker event error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(400, nil).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error with digital ocean snapshot server action/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker retrieve snapshots error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active', { snapshot_ids: [] }).times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /finished snapshotting server on digital ocean, but unable to get latest snapshot id/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'wait for snapshotting server worker delete error' do
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_do_droplet_action_show(1, 1).stub_do_droplet_action_show(200, 'completed').times_only(1)
    mock_do_droplet_delete(400, 1).times_only(1)
    WaitForSnapshottingServerWorker.perform_in(0.seconds, @minecraft.user_id, @minecraft.server.id, 1)
    WaitForSnapshottingServerWorker.perform_one
    assert_equal 0, WaitForSnapshottingServerWorker.jobs.size, 'Worker should have finished'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error destroying server on digital ocean \(has been snapshotted and saved\)/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server pending operation'
  end

  test 'start minecraft worker remote doesn\'t exist' do
    @minecraft.server.update_columns(remote_id: nil)
    StartMinecraftWorker.perform_in(0.seconds, @minecraft.server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error starting server; remote_id is nil/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'start minecraft worker remote error' do
    mock_do_droplet_show(1).stub_do_droplet_show(400, nil).times_only(1)
    StartMinecraftWorker.perform_in(0.seconds, @minecraft.server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have failed and exited'
    @minecraft.reload
    assert_equal 1, @minecraft.logs.count, 'Should have one server log'
    assert_match /error communicating with digital ocean while starting server/i, @minecraft.logs.first.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server'
  end

  test 'start minecraft worker node resume error' do
    mock_do_base(200)
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    mock_mcsw_start(@minecraft).stub_mcsw_start(400, @minecraft.server.ram)
    mock_do_image_delete(400, 1)
    @minecraft.update_columns(autoshutdown_enabled: true)
    @minecraft.server.update_columns(do_saved_snapshot_id: 1)
    StartMinecraftWorker.perform_in(0.seconds, @minecraft.server.id)
    StartMinecraftWorker.perform_one
    assert_equal 0, StartMinecraftWorker.jobs.size, 'Worker should have finished'
    assert_equal 1, AutoshutdownMinecraftWorker.jobs.size, 'Start Minecraft worker should have queued autoshutdown Minecraft worker'
    AutoshutdownMinecraftWorker.jobs.clear
    @minecraft.reload
    assert_equal 2, @minecraft.logs.count, 'Should have two server logs'
    assert_match /error starting minecraft on server/i, @minecraft.logs.sort.first.message
    assert_match /error deleting saved snapshot on digital ocean after starting server/i, @minecraft.logs.sort.second.message
    assert_not @minecraft.server.busy?, 'Worker should have reset server pending operation'
  end

  test 'autoshutdown minecraft worker exit conditions' do
    @minecraft.server.update_columns(remote_id: nil)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @minecraft.logs.count, 'Shouldn\'t have any server logs'

    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    @minecraft.server.update_columns(remote_id: 1)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @minecraft.logs.count, 'Shouldn\'t have any server logs'

    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(1)
    @minecraft.update_columns(autoshutdown_enabled: true)
    @minecraft.server.update_columns(pending_operation: 'saving')
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    AutoshutdownMinecraftWorker.perform_one
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal 0, @minecraft.logs.count, 'Shouldn\'t have any server logs'
  end

  test 'autoshutdown minecraft worker remote error' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(400, 'active').times_only(times)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @minecraft.logs.count, "Should have #{times} server logs"
    assert_match /error communicating with digital ocean while checking for autoshutdown/i, @minecraft.logs.first.message, 'Should have server log about error checking remote status'
    assert_nil @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker node error' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@minecraft).stub_mcsw_pid(200, 1, { status: 'badness' }).times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @minecraft.logs.count, "Should have #{times} server logs"
    assert_match /error getting minecraft pid/i, @minecraft.logs.first.message, 'Should have server log about error getting minecraft pid'
    assert_nil @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker server not active' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'off').times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @minecraft.logs.count, "Should have #{times} server logs"
    assert_match /checking for autoshutdown: remote status was off/i, @minecraft.logs.first.message, 'Should have server log about bad remote status'
    assert_nil @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end

  test 'autoshutdown minecraft worker players online' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE * 2
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@minecraft).stub_mcsw_pid(200, 1).times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    with_minecraft_query_server do |mcqs|
      mcqs.num_players = 1
      for i in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @minecraft.reload
    assert_equal 1, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should still be running'
    assert_equal 0, @minecraft.logs.count, 'Shouldn\'t have any server logs'
    assert_nil @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
    AutoshutdownMinecraftWorker.clear
  end

  test 'autoshutdown minecraft server error stopping' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_do_droplet_action(1).stub_do_droplet_action(400, 'shutdown')
    mock_mcsw_pid(@minecraft).stub_mcsw_pid(200, 1).times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    with_minecraft_query_server do |mcqs|
      for i in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should be done'
    assert_equal 1, @minecraft.logs.count, 'Should have 1 server log'
    assert_match /in autoshutdown worker, unable to stop server/i, @minecraft.logs.first.message, 'Should have server log about unable to stop server'
    assert_equal nil, @minecraft.server.pending_operation, "Autoshutdown Minecraft worker should have failed to stop server, but pending operation is #{@minecraft.server.pending_operation}"
    assert_equal 0, WaitForStoppingServerWorker.jobs.size, 'Wait for stopping server worker should have failed and not queued'
  end

  test 'autoshutdown minecraft worker pid 0' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_do_droplet_action(1).stub_do_droplet_action(200, 'shutdown')
    mock_mcsw_pid(@minecraft).stub_mcsw_pid(200, 0).times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    for i in 0...times
      AutoshutdownMinecraftWorker.perform_one
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should be done'
    assert_equal 0, @minecraft.logs.count, 'Shouldn\'t have any server logs'
    assert_equal 'stopping', @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker should have stopped server'
    assert_equal 1, WaitForStoppingServerWorker.jobs.size, 'Autoshutdown Minecraft worker should have queued wait for stopping server worker'
    WaitForStoppingServerWorker.clear
  end

  test 'autoshutdown minecraft worker error querying' do
    times = AutoshutdownMinecraftWorker::TIMES_TO_CHECK_MINUS_ONE + 1
    mock_do_droplet_show(1).stub_do_droplet_show(200, 'active').times_only(times)
    mock_mcsw_pid(@minecraft).stub_mcsw_pid(200, 1).times_only(times)
    @minecraft.update_columns(autoshutdown_enabled: true)
    AutoshutdownMinecraftWorker.perform_in(0.seconds, @minecraft.id)
    with_minecraft_query_server do |mcqs|
      mcqs.drop_packets = true
      for i in 0...times
        AutoshutdownMinecraftWorker.perform_one
      end
    end
    @minecraft.reload
    assert_equal 0, AutoshutdownMinecraftWorker.jobs.size, 'Autoshutdown Minecraft worker should have aborted'
    assert_equal times, @minecraft.logs.count, "Should have #{times} server logs"
    assert_match /error querying minecraft server/i, @minecraft.logs.first.message, 'Should have server log about error querying'
    assert_nil @minecraft.server.pending_operation, 'Autoshutdown Minecraft worker shouldn\'t have changed anything'
  end
end
