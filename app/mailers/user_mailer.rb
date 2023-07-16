class UserMailer < ActionMailer::Base
  helper :application

  default from: 'Gamocosm Mailer <no-reply@gamocosm.com>'

  def autoshutdown_error_email(server)
    @user = server.user
    @server = server
    mail(to: @user.email, subject: "Error trying to check/autoshutdown your server \"#{server.name}\"")
  end
end
