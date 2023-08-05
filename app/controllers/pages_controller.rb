class PagesController < ApplicationController
  # https://api.rubyonrails.org/classes/ActionController/RequestForgeryProtection/ClassMethods.html
  skip_forgery_protection only: [:not_found]

  def landing
    @nocontainer = true
  end

  def about
    @do_sizes = Gamocosm.digital_ocean.size_list
  end

  def tos; end

  def not_found
    render '404', status: 404, formats: :html
  end

  def badness
    if params[:secret] == ENV['BADNESS_SECRET']
      do_bad_things
    end
    redirect_to root_path
  end
end
