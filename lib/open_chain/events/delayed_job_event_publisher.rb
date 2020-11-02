require 'open_chain/events/event_publisher_support'
require 'open_chain/events/delayed_job_event_processor'

module OpenChain; module Events; class DelayedJobEventPublisher
  include OpenChain::Events::EventPublisherSupport

  def self.publish message_type, obj
    DelayedJobEventProcessor.delay.process(event_descriptor(message_type, obj))
    nil
  end

end; end; end