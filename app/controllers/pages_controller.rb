class PagesController < ApplicationController
  def landing
    @droplet_sizes = DigitalOcean::DropletSize.new.all.first(4)
    #@container_fluid = true
  end

  def about
  end

  def contact
  end

  def help
  end

  def tos
  end

  def digital_ocean_setup
  end
end
