require 'email_validator'

class RegistrationsController < ApplicationController
  include Recaptcha::Verify
  
  skip_before_filter :require_user
  
  def send_email
    valid_recaptcha = verify_recaptcha(timeout: 10)
    valid_email = EmailValidator.valid?(params[:email]) || params[:email].blank?

    {email: "Email", fname: "First Name", lname: "Last Name", 
     company: "Company", contact: "Contact"}.each { |k, v| add_flash(:errors, "You must fill in a value for '#{v}'.") if params[k].empty? }

    if !has_errors? && valid_recaptcha && valid_email
      OpenMailer.send_registration_request(params[:email], params[:fname], params[:lname], params[:company], params[:contact], params[:cust_no], MasterSetup.get.system_code).deliver_later
      render json: {flash: {notice: [
        "Thank you for registering, your request is being reviewed and you’ll receive a system invite shortly.\n\n" +
        "If you have any questions, please contact your Vandegrift account representative or support@vandegriftinc.com."
      ]}}
    else
      add_flash(:errors, "Please sign up with a valid email address.") unless valid_email
      add_flash(:errors, "Please verify you are not a robot.") unless valid_recaptcha
      render json: {flash: {errors: flash[:errors]}} 
    end
  end
end