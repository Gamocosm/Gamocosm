class RegistrationsController < Devise::RegistrationsController

  private

  def sign_up_params
    return params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :digital_ocean_api_key)
  end

  def account_update_params
    return params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :digital_ocean_api_key)
  end

  def after_update_path_for(resource)
    return edit_user_registration_path
  end

  def after_sign_up_path_for(resource)
    return minecrafts_path
  end
end
