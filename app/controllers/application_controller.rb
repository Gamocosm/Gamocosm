class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from ActionController::RoutingError, with: :not_found

  def after_sign_in_path_for(resource)
    servers_path
  end

  def not_found
    render 'pages/404', status: 404
  end
end
