module OpenChain; module Rspec; class InboundFileMatching
  def self.matches? log, status, message
    log.get_messages_by_status(status).map(&:message).include? message
  end

  def self.failure_message log, status, message
    "expected InboundFile to have #{status} message of '#{message}'.  It had: #{log.get_messages_by_status(status).map(&:message)}"
  end
end; end; end


RSpec::Matchers.define :have_info_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_INFO, message
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.failure_message actual, InboundFileMessage::MESSAGE_STATUS_INFO, message
  end
end

RSpec::Matchers.define :have_warning_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_WARNING, message
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.failure_message actual, InboundFileMessage::MESSAGE_STATUS_WARNING, message
  end
end

RSpec::Matchers.define :have_reject_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_REJECT, message
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.failure_message actual, InboundFileMessage::MESSAGE_STATUS_REJECT, message
  end
end

RSpec::Matchers.define :have_error_message do |message|
  match do |log|
    OpenChain::Rspec::InboundFileMatching.matches? log, InboundFileMessage::MESSAGE_STATUS_ERROR, message
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.failure_message actual, InboundFileMessage::MESSAGE_STATUS_ERROR, message
  end
end

RSpec::Matchers.define :have_identifier do |identifier_type, identifier_value, *args|
  match do |log|
    ids = Array.wrap(log.get_identifiers(identifier_type, value: identifier_value))
    arg_len = args.try(:length)
    if arg_len > 0
      if arg_len == 1
        module_type = args[0].class.to_s
        module_id = args[0].id
      else
        module_type = args[0].to_s
        module_id = args[1]
      end

      return !ids.find { |id| id.module_type == module_type && id.module_id == module_id }.nil?
    else
      return ids.length > 0
    end
  end
end