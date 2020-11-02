module OpenChain; module Events; class DelayedJobEventProcessor

  def self.process event_hash
    self.new.process_event event_hash
  end

  def process_event event_hash
    ActiveRecord::Base.transaction do
      object = EventSubscription.object_for_event_type(event_hash[:event_type], event_hash[:id])
      return if object.nil?

      process_system_message_events event_hash, object
      process_email_events event_hash, object
    end
  end

  def self.send_email_event user_id, event_hash
    user = User.find_by(id: user_id)
    return if user.nil?
    OpenMailer.send_event_notification(user, event_hash[:short_message], event_hash[:long_message], event_hash[:link]).deliver_now
    nil
  end

  def self.send_system_message_event user_id, event_hash
    user = User.find_by(id: user_id)
    return if user.nil?

    body = <<~BODY
      <p class="system-message-event">#{event_hash[:long_message]}</p>
      <p>#{event_hash[:link].present? ? "<a href='#{event_hash[:link]}'>Link</a>" : ""}</p>
    BODY

    user.messages.create! subject: event_hash[:short_message], body: body
    nil
  end

  private

    def process_email_events event_hash, object
      subscriptions = EventSubscription.subscriptions_for_event(event_hash[:event_type], :email, object: object)
      subscriptions.each do |subscription|
        self.class.delay.send_email_event(subscription.user.id, event_hash)
      end
    end

    def process_system_message_events event_hash, object
      subscriptions = EventSubscription.subscriptions_for_event(event_hash[:event_type], :system_message, object: object)
      subscriptions.each do |subscription|
        self.class.delay.send_system_message_event(subscription.user.id, event_hash)
      end
    end

end; end; end