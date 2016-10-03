require 'spec_helper'

describe RegistrationsController do
  before(:each) do
    @system_code = "HAL9000"
      allow_any_instance_of(MasterSetup).to receive(:system_code).and_return @system_code
      @email = "john_doe@acme.com"
      @fname = "John"
      @lname = "Doe"
      @company = "Acme"
      @cust_no = "123456789"
      @contact = "Jane Smith"
  end

  describe "send_email" do
    it "emails Vandegrift with the registration form data and the server's system_code" do
      
      post :send_email, email: @email, fname: @fname, lname: @lname, company: @company, cust_no: @cust_no, contact: @contact
      mail = ActionMailer::Base.deliveries.pop
      thanks = "Thank you for registering, your request is being reviewed and you’ll receive a system invite shortly.\n\n" +
               "If you have any questions, please contact your Vandegrift account representative or support@vandegriftinc.com."
      
      expect(mail.subject).to eq "Registration Request (HAL9000)"
      expect(response.body).to eq ({flash: {notice: [thanks]}}.to_json)
    end
    
    it "validates presence of email, first name, last name, company, contact" do
      post :send_email, email: "", fname: "", lname: "", company: "", cust_no: @cust_no, contact: ""
      expect(response.body).to eq ({flash: {errors: ["Email cannot be blank", "First name cannot be blank", "Last name cannot be blank", 
                                                     "Company cannot be blank", "Contact cannot be blank"]}}.to_json)
      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end

    it "validates well-formedness of email" do
      post :send_email, email: "vandegriftinc.com", fname: @fname, lname: @lname, company: @company, cust_no: @cust_no, contact: @contact      
      expect(response.body).to eq ({flash: {errors: ["Email is invalid"]}}.to_json)

      mail = ActionMailer::Base.deliveries.pop
      expect(mail).to be_nil
    end
  end
end