describe Message do
  let(:user) { FactoryBot(:user) }

  describe 'can_view?' do
    let(:msg) { FactoryBot(:message) }

    it "returns true for sys_admin" do
      user.sys_admin = true; user.save!
      expect(msg.can_view?(user)).to eq true
    end

    it "returns true for message owner" do
      msg.user = user; msg.save!
      expect(msg.can_view?(user)).to eq true
    end

    it "returns false for anyone else" do
      expect(msg.can_view?(user)).to eq false
    end
  end

  describe 'unread_message_count' do

    it 'returns number if unread messages exist' do
      FactoryBot(:message, user: user, viewed: false) # not viewed should be counted
      FactoryBot(:message, user: user) # no viewed value should be counted
      FactoryBot(:message, user: user, viewed: true) # viewed should not be counted
      expect(described_class.unread_message_count(user.id)).to eq(2)
    end
  end

  describe "run_schedulable" do
    it "implements SchedulableJob interface" do
      expect(described_class).to receive(:purge_messages)
      described_class.run_schedulable
    end
  end

  describe "email_to_user" do
    before { user.update! email_new_messages: true }

    let(:mail) { instance_double(ActionMailer::MessageDelivery) }

    it "sends emails to user who gets a system message" do
      expect(OpenMailer).to receive(:send_message).with(instance_of(described_class)).and_return mail
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
      u1 = FactoryBot(:user)
      u2 = FactoryBot(:user)
      described_class.send_to_users([u1.id, u2.id], "Test Message", "This is a test.")

      expect(u1.messages.first.subject).to eq "Test Message"
      expect(u1.messages.first.body).to eq "This is a test."
      expect(u2.messages.first.subject).to eq "Test Message"
      expect(u2.messages.first.body).to eq "This is a test."
    end
  end

end
