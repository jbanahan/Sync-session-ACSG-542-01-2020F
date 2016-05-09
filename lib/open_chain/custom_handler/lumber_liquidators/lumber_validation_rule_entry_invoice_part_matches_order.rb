require 'open_chain/api/order_api_client'

module OpenChain; module CustomHandler; module LumberLiquidators
  class LumberValidationRuleEntryInvoicePartMatchesOrder < BusinessValidationRule

    def run_validation entry
      order_cache = {}
      bad_invoices = {missing_part_no: [], mismatched_part: [], missing_po: [], failed_rule: []}
      entry.commercial_invoice_lines.each do |line|
        tag = {number: line.commercial_invoice.invoice_number, po: line.po_number, part: line.part_number}
        match_errors(line, order_cache).each{ |err| bad_invoices[err] << tag }
      end
      create_error_msg bad_invoices
    end

    def match_errors cil, order_cache
      errors = []
      order = cil.po_number.presence ? (get_order cil.po_number, order_cache) : nil
      if order["order"]
        errors << :failed_rule if order["order"]["ord_rule_state"] == "Fail"
        check_part cil, order, errors
      else
        errors << :missing_po
      end 
      errors
    end

    def get_order ord_num, order_cache
      unless order_cache.key? ord_num
        order_cache[ord_num] = OpenChain::Api::OrderApiClient.new("ll").find_by_order_number ord_num, [:ord_rule_state, :ordln_puid]
      end
      order_cache[ord_num].dup
    end

    def check_part cil, order, errors
      if cil.part_number.presence    
          part_matched = false
          order["order"]["order_lines"].each do |line| 
            product_uid = line["ordln_puid"].gsub(/^0+/, "")
            part_matched = true if cil.part_number == product_uid
          end
          errors << :mismatched_part unless part_matched
      else
        errors << :missing_part_no
      end
    end

    def create_error_msg bad_invoices
      errors = ""
      error_set.each do |error|
        if bad_invoices[error[:type]].presence
          errors << error[:msg]
          segments = []
          bad_invoices[error[:type]].each do |err| 
            data_str = "#{err[:number]}"
            data_str << " PO #{err[:po]}" if err[:po].presence
            data_str << " part #{err[:part]}" if err[:part].presence
            segments << data_str
          end
          errors << segments.uniq.join(", ") << "\n\n"
        end
      end
      errors.presence
    end

    def error_set
      [
        {:type => :mismatched_part, :msg => "The following invoices have POs that don't match their part numbers: "},
        {:type => :missing_po, :msg => "The part number for the following invoices do not have a matching PO: " },
        {:type => :missing_part_no, :msg => "The following invoices are missing a part number: " }, 
        {:type => :failed_rule, :msg => "Purchase orders associated with the following invoices have a failing business rule: "}
      ]
    end

  end
end; end; end