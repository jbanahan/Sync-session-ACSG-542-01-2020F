describe OpenChain::Events::DelayedJobEventProcessor do

  describe "process_event" do
    let (:object) { create(:order) }
    let (:event_hash) { OpenChain::Events::DelayedJobEventPublisher.event_descriptor(:order_create, object) }
    let (:user) { create(:user) }
    let! (:subscription) { EventSubscription.create! event_type: "order_create", system_message: true, email: true, user_id: user.id }
    let! (:master_setup) { stub_master_setup }

    it "determines subscriptions for system messages and email events" do
      allow_any_instance_of(Order).to receive(:can_view?).with(user).and_return true
      allow_any_instance_of(User).to receive(:active?).and_return true

      expect(described_class).to receive(:delay).twice.and_return described_class
      expect(described_class).to receive(:send_email_event).with(user.id, event_hash)
      expect(described_class).to receive(:send_system_message_event).with(user.id, event_hash)

      subject.process_event event_hash
    end

    it "does not send email if user is not subscribed to anything" do
      subscription.destroy

      expect(described_class).not_to receive(:delay)
      expect(described_class).not_to receive(:send_email_event).with(user.id, event_hash)
      expect(described_class).not_to receive(:send_system_message_event).with(user.id, event_hash)

      subject.process_event event_hash
    end
  end

  describe "send_email_event" do

    subject { described_class }

    let (:user) { create(:user) }
    let (:object) { Order.new id: 1 }
    let (:event_hash) { OpenChain::Events::DelayedJobEventPublisher.event_descriptor(:order_create, object) }

    it "sends email" do
      subject.send_email_event user.id, event_hash

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq [user.email]
      expect(mail.subject).to include event_hash[:short_message]
      expect(mail.body).to include event_hash[:long_message]
      expect(mail.body).to include event_hash[:link]
    end

    it "does nothing if user isn't found" do
      user.destroy
      subject.send_email_event user.id, event_hash
      expect(ActionMailer::Base.deliveries).to be_blank
    end

  end

  describe "send_system_message_event" do

    subject { described_class }

    let (:user) { create(:user) }
    let (:object) { Order.new id: 1 }
    let (:event_hash) { OpenChain::Events::DelayedJobEventPublisher.event_descriptor(:order_create, object) }

    it "sends system message" do
      subject.send_system_message_event user.id, event_hash
      m = user.messages.first
      expect(m.subject).to eq event_hash[:short_message]
      expect(m.body).to include event_hash[:long_message]
      expect(m.body).to include event_hash[:link]
    end

    it "does nothing if user isn't found" do
      user.destroy
      subject.send_system_message_event user.id, event_hash
    end

  end

end