require 'open_chain/email_processor'
Griddler.configure do |config|
  config.processor_class = OpenChain::EmailProcessor
  config.email_service = :postmark
end