require 'email_validator'

class RegistrationsController < ApplicationController
  skip_before_filter :require_user
  
  def send_email
    sys_code = MasterSetup.get.system_code

    thanks = "Thank you for registering, your request is being reviewed and you’ll receive a system invite shortly.\n\n" +
             "If you have any questions, please contact your Vandegrift account representative or support@vandegriftinc.com."

    {email: "Email", fname: "First name", lname: "Last name", 
     company: "Company", contact: "Contact"}.each { |k, v| add_flash(:errors, "#{v} cannot be blank") if params[k].empty? }

    add_flash :errors, "Email is invalid" unless EmailValidator.valid?(params[:email]) || params[:email].blank?

    unless flash[:errors]
        fields = params.dup.merge(system_code: sys_code)
        OpenMailer.send_registration_request(fields).deliver!
        render json: {flash: {notice: [thanks]}}
      else 
        render json: {flash: {errors: flash[:errors]}} 
    end
  end
end