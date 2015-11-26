class ScheduledTaskWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(x)
    begin
      actual = ScheduledTask::Partition.server_current
      dt_string = DateTime.current.strftime('%Y %b %-d %H:%M %Z')
      if !actual.valid?
        msg = "ScheduledTaskWorker running at not valid #{actual.value} (#{dt_string}), rescheduling"
        logger.error msg
        ExceptionNotification.notify_exception(RuntimeError.new(msg))
        return
      end
      if x != actual.snap
        msg = "ScheduledTaskWorker running at #{actual.value} (#{dt_string}), expected at #{x}"
        logger.error msg
        ExceptionNotification.notify_exception(RuntimeError.new(msg))
      end
      ScheduledTask.find_by(partition: actual.snap).each do |task|
        begin
          case task.action
          when 'start'
            error = task.server.start
            if error
              task.server.log("Error starting server on schedule: #{error}")
            end
          when 'stop'
            error = task.server.stop
            if error
              task.server.log("Error stopping server on schedule: #{error}")
            end
          else
            task.server.log("Something went wrong in the schedule! Unrecognized action #{task.action}")
            msg = "ScheduledTask encountered unknown action #{task.action} for task #{task.id}, server #{task.server_id}"
            logger.error msg
            ExceptionNotification.notify_exception(RuntimeError.new(msg))
          end
        rescue => e
          task.server.log("Something went wrong in the schedule! Exception #{e.inspect}")
          logger.error "ScheduledTaskWorker encountered error with task #{task.id}, server #{task.server_id}: #{e.inspect}"
          logger.error e.backtrace.join
          ExceptionNotification.notify_exception(e)
        end
      end
    rescue => e
      logger.error "Unhandled error in ScheduledTaskWorker! #{e.inspect}"
      raise e
    ensure
      self.schedule_self
    end
  end

  def schedule_self
    actual = ScheduledTask::Partition.server_current
    minutes = actual.next - actual.value
    # doesn't take into account seconds, but should never be off by more than a minute, and should re-adjust when it passes a minute
    ScheduledTaskWorker.perform_in((minutes * 60).seconds, actual.next)
  end
end
