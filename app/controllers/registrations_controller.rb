class RegistrationsController < ApplicationController
  skip_before_filter :require_user
  
  def send_email
    system_code = MasterSetup.get.system_code
    email_body =
        "REGISTRATION REQUEST\n\n" +
        "Email: #{params[:email]}\n" +
        "First Name: #{params[:fname]}\n" +
        "Last Name: #{params[:lname]}\n" +
        "Company: #{params[:company]}\n" +
        "Customer Number: #{params[:cust_no]}\n" +
        "Contact: #{params[:contact]}\n" +
        "System Code: #{system_code}"

    thanks = "Thank you for registering, your request is being reviewed and you’ll receive a system invite shortly.\n\n" +
             "If you have any questions, please contact your Vandegrift account representative or support@vandegriftinc.com."

    {email: "Email", fname: "First name", lname: "Last name", 
     company: "Company", contact: "Contact"}.each { |k, v| add_flash(:errors, "#{v} cannot be blank") if params[k].empty? }

    regex = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i  #http://stackoverflow.com/a/22994329
    add_flash :errors, "Email is invalid" unless regex =~ params[:email] || params[:email].blank?

    unless flash[:errors]
        OpenMailer.send_simple_text("jdavis@vandegriftinc.com", "Registration Request", email_body).deliver!
        render json: {flash: {notice: [thanks]}}
      else 
        render json: {flash: {errors: flash[:errors]}} 
    end
  end
end