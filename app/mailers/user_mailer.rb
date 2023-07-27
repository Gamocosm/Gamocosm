class UserMailer < ActionMailer::Base
  helper :application

  default from: Gamocosm::MAILER

  def autoshutdown_error_email(server)
    @user = server.user
    @server = server
    mail(to: @user.email, subject: "Could not check/autoshutdown your server '#{server.name}'.")
  end
end
