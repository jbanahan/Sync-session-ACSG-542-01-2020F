describe Message do
  describe 'unread_message_count' do
    before :each do
      @u = Factory(:user)
    end
    it 'should return number if unread messages exist' do
      Factory(:message,:user=>@u,:viewed=>false) #not viewed should be counted
      Factory(:message,:user=>@u) #no viewed value should be counted
      Factory(:message,:user=>@u,:viewed=>true) #viewed should not be counted
      expect(Message.unread_message_count(@u.id)).to eq(2)
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(Message).to receive(:purge_messages)
      Message.run_schedulable
    end
  end

  describe "email_to_user" do
    let(:user) { Factory(:user, email_new_messages: true) }
    let(:mail) { instance_double(ActionMailer::MessageDelivery) }

    it "sends emails to user who gets a system message" do
      expect(OpenMailer).to receive(:send_message).with(instance_of(Message)).and_return mail
      expect(mail).to receive(:deliver_later)

      user.messages.create! subject: "Subject", body: "Body"
    end

    it "does not send email to user that doesn't want them" do
      user.email_new_messages = false
      user.save!
      expect(OpenMailer).not_to receive(:send_message)
      user.messages.create! subject: "Subject", body: "Body"
    end

    it "doesn't send email to disabled users" do
      user.disabled = true
      user.save!

      expect(OpenMailer).not_to receive(:send_message)
      user.messages.create! subject: "Subject", body: "Body"
    end
  end

  describe "send_to_users" do
    it "distributes message to specified users" do
      u1 = Factory(:user)
      u2 = Factory(:user)
      described_class.send_to_users([u1.id, u2.id], "Test Message", "This is a test.")

      expect(u1.messages.first.subject).to eq "Test Message"
      expect(u1.messages.first.body).to eq "This is a test."
      expect(u2.messages.first.subject).to eq "Test Message"
      expect(u2.messages.first.body).to eq "This is a test."
    end
  end

end
