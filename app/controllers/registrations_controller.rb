class RegistrationsController < Devise::RegistrationsController

  private

  def account_update_params
    return params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :digital_ocean_client_id, :digital_ocean_api_key)
  end
end
