require 'open_chain/custom_handler/ascena/ascena_invoice_validator_helper'

module OpenChain; module CustomHandler; module Ascena
  class ValidationRuleAscenaInvoiceAudit < BusinessValidationRule
    MAX_LENGTH ||= 65535

    def run_validation entry
      helper = OpenChain::CustomHandler::Ascena::AscenaInvoiceValidatorHelper.new
      errors = screen_for_long_message(helper.audit(entry, rule_attributes["style_list"]))
      errors unless errors.empty?
    end

    private

    def screen_for_long_message errors
      if errors.length > MAX_LENGTH
        errors = "This message is too long to be displayed in its entirety. " \
                 "Resolve the following errors to see the remainder:\n\n" + errors[0..(MAX_LENGTH - 1 - 110 - 3)] + '...'
      end
      errors
    end
  end
end; end; end