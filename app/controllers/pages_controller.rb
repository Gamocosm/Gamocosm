class PagesController < ApplicationController
  def landing
    @nocontainer = true
  end

  def about
  end

  def info
    @do_sizes = Gamocosm.digital_ocean.size_list
  end

  def tos
  end

  def digital_ocean_setup
  end

  def demo
    @minecraft = Mock::Mocker.new.mock_minecraft(Minecraft.new)
    server = Mock::Server.new
    server.minecraft = @minecraft
    server.do_region_slug = 'nyc3'
    server.do_size_slug = '1gb'
    server.remote_setup_stage = 5
    server.remote_id = 1
    @minecraft.server = server
    user = User.new
    user.digital_ocean_api_key = 'abc'
    @minecraft.user = user
    @minecraft.domain = 'abcdefgh'
    @minecraft.autoshutdown_enabled = true
    @minecraft.autoshutdown_last_check = Time.now - 32.seconds
    @minecraft.autoshutdown_last_successful = Time.now - 32.seconds
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
