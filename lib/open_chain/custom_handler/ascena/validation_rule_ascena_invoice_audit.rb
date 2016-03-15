require 'open_chain/custom_handler/ascena/ascena_invoice_validator_helper'

module OpenChain; module CustomHandler; module Ascena
  class ValidationRuleAscenaInvoiceAudit < BusinessValidationRule
    MAX_LENGTH ||= 65535

    def run_validation entry
      style_list = rule_attributes["style_list"]
      style_set = style_list ? rule_attributes["style_list"].to_set : nil
      validator = OpenChain::CustomHandler::Ascena::AscenaInvoiceValidatorHelper.new
      
      validator.run_queries entry
      execute_tests validator, style_set
    end

    private

    def execute_tests validator, style_set
      errors = []
      errors << validator.invoice_list_diff
      if errors.first.blank?
        errors << validator.total_value_per_hts_coo_diff
        errors << validator.total_qty_per_hts_coo_diff
        errors << validator.total_value_diff
        errors << validator.total_qty_diff
        errors << validator.hts_set_diff
        errors << validator.style_set_match(style_set) if style_set
      end
      errors = errors.reject{ |err| err.empty? }.join("\n")
      errors = screen_for_long_message errors
      errors unless errors.empty?
    end

    def screen_for_long_message errors
      if errors.length > MAX_LENGTH
        errors = "This message is too long to be displayed in its entirety. " \
                 "Resolve the following errors to see the remainder:\n\n" + errors[0..(MAX_LENGTH - 1 - 110 - 3)] + '...'
      end
      errors
    end
  end
end; end; end