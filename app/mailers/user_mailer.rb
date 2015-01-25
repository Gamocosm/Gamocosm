class UserMailer < ActionMailer::Base
  default from: 'no-reply@gamocosm.com'

  def autoshutdown_error_email(minecraft)
    @user = minecraft.user
    @minecraft = minecraft
    mail(to: @user.email, subject: "Error trying to check/autoshutdown your server \"#{minecraft.name}\"")
  end
end
