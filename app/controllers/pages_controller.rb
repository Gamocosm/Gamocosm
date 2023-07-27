class PagesController < ApplicationController
  def landing
    @nocontainer = true
  end

  def about
    @do_sizes = Gamocosm.digital_ocean.size_list
  end

  def tos; end

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
    redirect_to root_path
  end
end
