module OpenChain; module Rspec; class InboundFileMatching
  def self.matches? log, status, message
    log.get_messages_by_status(status).map(&:message).include? message
  end

  def self.no_matches? log, status
    log.get_messages_by_status(status).length == 0
  end

  def self.failure_message log, status, message
    "expected InboundFile to have #{status} message of '#{message}'.  It had: #{log.get_messages_by_status(status).map(&:message)}"
  end

  def self.no_matches_failure_message log, status
    "expected InboundFile to have no messages of #{status} status.  It had: #{log.get_messages_by_status(status).map(&:message)}"
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

RSpec::Matchers.define :have_no_info_messages do
  match do |log|
    OpenChain::Rspec::InboundFileMatching.no_matches? log, InboundFileMessage::MESSAGE_STATUS_INFO
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.no_matches_failure_message actual, InboundFileMessage::MESSAGE_STATUS_INFO
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

RSpec::Matchers.define :have_no_warning_messages do
  match do |log|
    OpenChain::Rspec::InboundFileMatching.no_matches? log, InboundFileMessage::MESSAGE_STATUS_WARNING
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.no_matches_failure_message actual, InboundFileMessage::MESSAGE_STATUS_WARNING
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

RSpec::Matchers.define :have_no_reject_messages do
  match do |log|
    OpenChain::Rspec::InboundFileMatching.no_matches? log, InboundFileMessage::MESSAGE_STATUS_REJECT
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.no_matches_failure_message actual, InboundFileMessage::MESSAGE_STATUS_REJECT
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

RSpec::Matchers.define :have_no_error_messages do
  match do |log|
    OpenChain::Rspec::InboundFileMatching.no_matches? log, InboundFileMessage::MESSAGE_STATUS_ERROR
  end

  failure_message do |actual|
    OpenChain::Rspec::InboundFileMatching.no_matches_failure_message actual, InboundFileMessage::MESSAGE_STATUS_ERROR
  end
end

RSpec::Matchers.define :have_identifier do |identifier_type, identifier_value, *args|
  # This allows the identifier_type to be provided as either InboundFileIdentifier::SOME_TYPE or :some_type.
  identifier_type = InboundFileIdentifier.translate_identifier(identifier_type)
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