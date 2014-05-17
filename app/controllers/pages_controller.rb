class PagesController < ApplicationController
  def landing
    @droplet_sizes = DigitalOcean::DropletSize.new.all.first(4)
  end

  def about
  end

  def contact
  end

  def help
  end
end
