class RegistrationsController < Devise::RegistrationsController
  def update
    current_user.invalidate
    super
  end

  private
  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :digital_ocean_api_key)
  end

  def account_update_params
    params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :digital_ocean_api_key)
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  def after_sign_up_path_for(resource)
    servers_path
  end
end
