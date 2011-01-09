class OpenMailer < ActionMailer::Base
  default :from => "test@brian-glick.com"

  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.open_mailer.send_change.subject
  #
  def send_change(history,subscription,text_only)
    details = history.details_hash
    type = details[:type].nil? ? "Item" : details[:type]
    identifier = details[:identifier].nil? ? "[unknown]" : details[:identifier]
    @detail_hash = details
    if !text_only
      mail(:to => subscription.user.email, :subject => "#{type} #{identifier} changed.") do |format|
        format.html
      end
    else
      mail(:to => subscription.user.email, :subject => "#{type} #{identifier} changed. [txt]") do |format|
        format.text
      end
    end
  end
  
  def send_feedback(current_user,params,request)
    @user = current_user
    @params = params
    @request = request
    mail(:to => 'chainio-feedback@aspect9.com',
          :subject => "[Chain.io User Feedback] from #{current_user.full_name} @ #{current_user.company.name}")
          
    
  end
end
