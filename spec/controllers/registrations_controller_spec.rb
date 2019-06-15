describe RegistrationsController do
  let! (:master_setup) { stub_master_setup }
  let (:params) {
    {
      email: "john_doe@acme.com",
      fname: "John",
      lname: "Doe",
      company: "Acme",
      cust_no: "123456789",
      contact: "Jane Smith"
    }
  }

  describe "send_email" do

    context "with valid recaptcha", :disable_delayed_jobs do

      before :each do 
        allow(subject).to receive(:verify_recaptcha).with(timeout: 10).and_return true
      end

      it "emails Vandegrift with the registration form data and the server's system_code" do
        message_delivery = instance_double(ActionMailer::MessageDelivery)
        expect(OpenMailer).to receive(:send_registration_request).with("john_doe@acme.com", "John", "Doe", "Acme", "Jane Smith", "123456789", MasterSetup.get.system_code).and_return message_delivery
        expect(message_delivery).to receive(:deliver_later)

        post :send_email, params
        thanks = "Thank you for registering, your request is being reviewed and you’ll receive a system invite shortly.\n\n" +
                 "If you have any questions, please contact your Vandegrift account representative or support@vandegriftinc.com."
        
        expect(response.body).to eq ({flash: {notice: [thanks]}}.to_json)
      end
      
      it "validates presence of email, first name, last name, company, contact" do
        [:email, :fname, :lname, :company, :contact].each {|k| params[k] = "" }

        post :send_email, params
        expect(response.body).to eq ({flash: {errors: ["You must fill in a value for 'Email'.", "You must fill in a value for 'First Name'.", 
                                                       "You must fill in a value for 'Last Name'.", "You must fill in a value for 'Company'.",
                                                       "You must fill in a value for 'Contact'."]}}.to_json)
        expect(ActionMailer::Base.deliveries).to be_blank
      end

      it "validates well-formedness of email" do
        params[:email] = "vandegriftinc.com"
        post :send_email, params
        expect(response.body).to eq ({flash: {errors: ["Please sign up with a valid email address."]}}.to_json)

        expect(ActionMailer::Base.deliveries).to be_blank
      end
    end

    context "without a valid recaptcha validation" do
      before :each do 
        allow(subject).to receive(:verify_recaptcha).with(timeout: 10).and_return false
      end

      it "errors" do
        post :send_email, params
        expect(response.body).to eq ({flash: {errors: ["Please verify you are not a robot."]}}.to_json)

        expect(ActionMailer::Base.deliveries).to be_blank
      end
    end
  end
end