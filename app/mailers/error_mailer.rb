class ErrorMailer < ActionMailer::Base
  default :from => "notifications@aspect9.com"
  
  def search_error_email(user)
    @user = user
    mail(:to => user.email, :subject => "Aspect 9 - Search Error Notification")
  end
end
