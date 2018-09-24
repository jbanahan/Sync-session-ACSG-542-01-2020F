module OpenChain; module Rspec; class InboundFileMatching
  def self.matches? log, status, message
    log.get_messages_by_status(status).map(&:message).include? message
  end
end; end; end


RSpec::Matchers.define :have_info_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_INFO, message
  end
end

RSpec::Matchers.define :have_warning_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_WARNING, message
  end
end

RSpec::Matchers.define :have_reject_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_REJECT, message
  end
end

RSpec::Matchers.define :have_error_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_ERROR, message
  end
end

RSpec::Matchers.define :have_identifier do |identifier_type, identifier_value|
  match do |log|
    Array.wrap(log.get_identifiers(identifier_type, value: identifier_value)).length > 0
  end
end