module OpenChain; module CustomHandler; module AnnInc; class AnnFirstSaleValidationRule < BusinessValidationRule

  def run_validation entry
    errors = []
    entry.commercial_invoices.each do |ci|
      customer_invoice = Invoice.includes(:invoice_lines).where(importer_id: entry.importer_id, invoice_number: ci.invoice_number).first
      if !customer_invoice
        errors << "No matching customer invoice was found for commercial invoice #{ci.invoice_number}.\n"
      end
      next unless customer_invoice
      ci_errors = run_tests ci, customer_invoice
      if ci_errors
        errors << "Errors found on commercial invoice #{ci.invoice_number}:\n" + ci_errors
      end
    end
    errors.join("\n\n").presence
  end

  def run_tests commercial_invoice, customer_invoice
    errors = []
    errors << fs_flag_is_false(commercial_invoice, customer_invoice)
    errors << fs_flag_is_true(commercial_invoice, customer_invoice)
    errors << fs_value_set(commercial_invoice)
    errors << fs_not_applied(commercial_invoice, customer_invoice)
    errors << fs_on_invoices_match(commercial_invoice, customer_invoice)
    errors << fs_is_only_discount(commercial_invoice)
    errors << fs_applied_instead_of_ci_discount(commercial_invoice, customer_invoice)
    errors << air_sea_eq_non_dutiable(commercial_invoice, customer_invoice)
    errors << other_amount_eq_trade_discount(commercial_invoice, customer_invoice)
    errors << early_pay_eq_misc_discount(commercial_invoice, customer_invoice)
    errors << no_missing_discounts(commercial_invoice, customer_invoice)
    errors << fs_applied_instead_of_cust_inv_discount(commercial_invoice, customer_invoice)
    errors.compact.uniq.join("\n").presence
  end

  def first_sale? cil
    (cil.contract_amount && cil.contract_amount > 0).present?
  end

  def commercial_invoice_line_discount cil
    trap_nil(cil.non_dutiable_amount) + flip(cil.other_amount) + trap_nil(cil.miscellaneous_discount)
  end

  def customer_invoice_line_discount il
    trap_nil(il.air_sea_discount) + trap_nil(il.trade_discount) + trap_nil(il.early_pay_discount)
  end

  def find_matching_line cust_invoice, cil, errors
    lines = cust_invoice.invoice_lines.select { |il| il.po_number == cil.po_number && il.part_number == cil.part_number}
    if lines.empty?
      errors << "On line #{cil.line_number}, no matching customer invoice line found with PO number #{cil.po_number} and part number #{cil.part_number}."
      return nil
    end
    lines.find { |il| yield il, customer_invoice_line_discount(il) }
  end

  def trap_nil field
    field || 0
  end

  # used only for #other_amount, which acts as a credit unless it's negative
  def flip field
    trap_nil(field) * -1
  end

  # TESTS

  def fs_flag_is_false ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next unless first_sale?(cil)
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(il.middleman_charge) < discount }
      if cust_inv_line
        errors << "On line #{cil.line_number}, First Sale amount of #{trap_nil cust_inv_line.middleman_charge} is less than Other Discounts amount of #{customer_invoice_line_discount(cust_inv_line)}, but First Sale flag is set to True."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_flag_is_true ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil)
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(il.middleman_charge) > discount }
      if cust_inv_line
        errors << "On line #{cil.line_number}, First Sale amount of #{trap_nil cust_inv_line.middleman_charge} is greater than Other Discounts amount of #{customer_invoice_line_discount(cust_inv_line)}, but the First Sale flag is set to False."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_value_set ci
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next unless first_sale?(cil)
      unless trap_nil(cil.non_dutiable_amount) > 0
        errors << "On line #{cil.line_number}, First Sale flag is set, but no First Sale value was entered."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_not_applied ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if !first_sale?(cil) || trap_nil(cil.non_dutiable_amount).zero?
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(il.middleman_charge) < discount }
      if cust_inv_line
        errors << "On line #{cil.line_number}, Other Discounts amount of #{customer_invoice_line_discount(cust_inv_line)} is greater than the First Sale amount of #{trap_nil cust_inv_line.middleman_charge}, but the First Sale discount was applied."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_on_invoices_match ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next unless first_sale?(cil) && trap_nil(cil.non_dutiable_amount) > 0
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(il.middleman_charge) != cil.non_dutiable_amount }
      if cust_inv_line
        errors << "On line #{cil.line_number}, First Sale amount of #{trap_nil cust_inv_line.middleman_charge} should equal the Non-Dutiable amount of the commercial invoice, #{cil.non_dutiable_amount}."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_is_only_discount ci
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next unless first_sale?(cil) && trap_nil(cil.non_dutiable_amount) > 0
      discounts = trap_nil(cil.miscellaneous_discount) + flip(cil.other_amount)
      if discounts > 0
        errors << "On line #{cil.line_number}, with First Sale Flag set to True only a Non-Dutiable amount greater than 0 is allowed. Other Discounts for the commercial invoice are #{discounts}."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_applied_instead_of_ci_discount ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil) || commercial_invoice_line_discount(cil).zero?
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| discount < trap_nil(il.middleman_charge) }
      if cust_inv_line
        errors << "On line #{cil.line_number}, Other Discounts amount of #{customer_invoice_line_discount(cust_inv_line)} is less than First Sale Discount of #{trap_nil cust_inv_line.middleman_charge}, but was applied anyway."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def air_sea_eq_non_dutiable ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil) || commercial_invoice_line_discount(cil).zero?
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(cil.non_dutiable_amount) != trap_nil(il.air_sea_discount) }
      if cust_inv_line
        errors << "On line #{cil.line_number}, Air/Sea Discount amount of #{trap_nil cust_inv_line.air_sea_discount} should equal the Non-Dutiable Amount of the commercial invoice, #{trap_nil cil.non_dutiable_amount}, when First Sale flag is set to False."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def other_amount_eq_trade_discount ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil) || commercial_invoice_line_discount(cil).zero?
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| flip(cil.other_amount) != trap_nil(il.trade_discount) }
      if cust_inv_line
        errors << "On line #{cil.line_number}, Trade Discount amount of #{trap_nil cust_inv_line.trade_discount} should equal the Other Adjustments Amount of the commercial invoice, #{flip cil.other_amount}, when First Sale flag is set to False."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def early_pay_eq_misc_discount ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil) || commercial_invoice_line_discount(cil).zero?
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| trap_nil(cil.miscellaneous_discount) != trap_nil(il.early_pay_discount) }
      if cust_inv_line
        errors << "On line #{cil.line_number}, Early Payment Discount amount of #{trap_nil cust_inv_line.early_pay_discount} should match the Miscellaneous Discount of the commercial invoice, #{trap_nil cil.miscellaneous_discount}, when the First Sale is set to False."
      end
    end
    errors.presence.try(:join, "\n")
  end

  def no_missing_discounts ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil) || commercial_invoice_line_discount(cil) > 0
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| discount > 0 }
      if cust_inv_line
        missing_fields = {"Air/Sea Discount" => cust_inv_line.air_sea_discount,
                          "Trade Discount" => cust_inv_line.trade_discount,
                          "Early Payment Discount" => cust_inv_line.early_pay_discount}.select { |k, v| trap_nil(v) > 0 }.map { |k, v| "#{k} (#{v})"}.join(", ")
        errors << "Line #{cust_inv_line.line_number} is missing the following discounts: #{missing_fields}"
      end
    end
    errors.presence.try(:join, "\n")
  end

  def fs_applied_instead_of_cust_inv_discount ci, cust_inv
    errors = []
    ci.commercial_invoice_lines.each do |cil|
      next if first_sale?(cil)
      cust_inv_line = find_matching_line(cust_inv, cil, errors) { |il, discount| discount < trap_nil(il.middleman_charge) }
      if cust_inv_line
        errors << "On line #{cil.line_number}, First Sale Discount amount of #{trap_nil cust_inv_line.middleman_charge} should have been applied to invoice but was not. Other Discounts were applied instead."
      end
    end
    errors.presence.try(:join, "\n")
  end


end; end; end; end
