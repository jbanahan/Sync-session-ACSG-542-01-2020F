require 'open_chain/sqs'
require 'open_chain/events/event_publisher_support'

module OpenChain; module Events; class SqsEventPublisher
  include OpenChain::Events::EventPublisherSupport

  def self.publish message_type, obj
    event_descriptor = event_descriptor(message_type, obj)
    # api token and host are specific things that the SQS handler would need, but not
    # necessarily other handlers.
    if event_descriptor[:api_token].blank?
      api_admin = User.api_admin
      event_descriptor[:api_token] = api_admin.user_auth_token
    end
    if event_descriptor[:host].blank?
      event_descriptor[:host] = MasterSetup.get.request_host
    end
    self.delay.send_to_sqs(event_descriptor.to_json)
    nil
  end

  def self.send_to_sqs event_descriptor
    OpenChain::SQS.send_json sqs_queue, event_descriptor
  end

  def self.sqs_queue
    config = MasterSetup.secrets[:sqs_event_publisher]
    raise "No SqsEventPublisher found in secrets.yml with key 'sqs_event_publisher'." if config.blank?
    config["queue_url"]
  end

end; end; end