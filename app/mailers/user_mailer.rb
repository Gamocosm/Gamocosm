class UserMailer < ActionMailer::Base
  default from: 'no-reply@gamocosm.com'

  def autoshutdown_error_email(user)
    @user = user
    mail(to: @user.email, subject: 'Error trying to check/autoshutdown your server')
  end
end
