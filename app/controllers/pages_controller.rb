class PagesController < ApplicationController
  def landing
    @nocontainer = true
  end

  def about
    @do_sizes = Gamocosm.digital_ocean.size_list
  end

  def tos
  end

  def digital_ocean_setup
  end

  def demo
    @server = Mock::Mocker.new.mock_server(Server.new)
    @server.domain = 'abcdefgh'
    @server.remote_region_slug = 'nyc3'
    @server.remote_size_slug = '1gb'
    @server.setup_stage = 5
    @server.remote_id = 1
    @server.timezone_delta = 0
    @server.scheduled_tasks = ScheduledTask.parse([
      'Wednesday 8:00 pm start',
      'Friday 3:30 pm start',
      'Sunday 11:00 am start',
    ].join("\n"), @server)

    minecraft = Mock::Minecraft.new
    minecraft.server = @server
    minecraft.autoshutdown_enabled = true
    minecraft.autoshutdown_last_check = Time.now - 32.seconds
    minecraft.autoshutdown_last_successful = Time.now - 32.seconds
    minecraft.autoshutdown_minutes = 8
    @server.minecraft = minecraft

    user = User.new
    user.digital_ocean_api_key = 'abc'
    @server.user = user

    @demo = true
  end

  def not_found
    render status: 404
  end

  def unacceptable
    render status: 422
  end

  def internal_error
    render status: 500
  end

  def badness
    if params[:secret] == ENV['BADNESS_SECRET']
      do_bad_things
    end
    return redirect_to root_path
  end
end
