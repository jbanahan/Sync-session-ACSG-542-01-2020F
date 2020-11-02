require 'open_chain/sqs'
require 'open_chain/events/event_publisher_support'

module OpenChain; class EventPublisher
  extend OpenChain::ServiceLocator

  def self.check_validity obj
    unless obj < OpenChain::Events::EventPublisherSupport
      raise "All EventPublishers must include OpenChain::Events::EventPublisherSupport."
    end
    raise "All EventPublishers must respond_to 'publish'." unless obj.respond_to?(:publish)

    true
  end

  def self.publish message_type, obj
    registered.each { |publisher| publisher.publish(message_type, obj) }
    nil
  end

end; end
