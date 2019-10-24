# For Ascena and Maurices entries. No JSON args.

module OpenChain; module CustomHandler; module Ascena; class ValidationRuleAscenaFirstSale < BusinessValidationRule
  ASCENA_CUST_NUM = "ASCE"
  MAURICES_CUST_NUM = "MAUR"

  def run_validation entry
    unless [ASCENA_CUST_NUM, MAURICES_CUST_NUM].include? entry.customer_number
      raise "Validation can only be run with customers '#{ASCENA_CUST_NUM}' and '#{MAURICES_CUST_NUM}'. Found: #{entry.customer_number}"
    end
    return nil unless entry.entry_filed_date

    # What we need to do here is ensure that every single invoice line on the entry that has an MID-VendorID that 
    # matches one of the MID-VendorIDs in their list (xref'ed type) and has a filed date after the FS start date in 
    # the corresponding xref has first sale data.

    xref = upcase_hash_keys DataCrossReference.hash_for_type(DataCrossReference::ASCE_MID)
    inv_line_data = results_by_inv_ln(ActiveRecord::Base.connection.exec_query query(entry.id, entry.customer_number))
    
    errors = []
    air = entry.transport_mode_code.to_s == "40"

    entry.commercial_invoices.each do |i|
      # Skip any envoice that ends with NFS (No Margin for Vendors (?)) or MIN (minimum)
      next if i.invoice_number.to_s.upcase.end_with?("NFS") || i.invoice_number.to_s.upcase.end_with?("MIN")

      i.commercial_invoice_lines.each do |l|
        # Skip if air entry and line has non-dutiable charges
        next if air && l.non_dutiable_amount.to_f > 0
 
        # query join will only skip lines with a bad PO#
        if inv_line_data[l.id].nil?
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} has an invalid PO number."
          next
        end

        if inv_line_data[l.id][:ord_mid].present? && (inv_line_data[l.id][:inv_mid] != inv_line_data[l.id][:ord_mid])
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must have an MID that matches to the PO. Invoice MID is '#{inv_line_data[l.id][:inv_mid]}' / PO MID is '#{inv_line_data[l.id][:ord_mid]}'"
        end
        
        if filed_after_fs_start?(entry.entry_filed_date, l.id, xref, inv_line_data) && invalid_first_sale_data?(l)
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must have Value Appraisal Method and Contract Amount set."
          next
        end
        
        if l.contract_amount.to_f > 0
          first_sale_checks i, l, errors, xref, inv_line_data
        elsif xref.keys.include? inv_line_data[l.id][:mid_vend]
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must not have a Vendor-MID combination on the approved first-sale list."
        end
      end
    end

    errors.length > 0 ? errors.uniq.join("\n") : nil
  end

  def first_sale_checks ci, cil, errors, xref_hsh, query_result_hsh
    if cil.contract_amount.to_f < cil.total_entered_value
      errors << "Invoice # #{ci.invoice_number} / Line # #{cil.line_number} must have a First Sale Contract Amount greater than the Entered Value."
    end
    if !xref_hsh.keys.include? query_result_hsh[cil.id][:mid_vend]
      errors << "Invoice # #{ci.invoice_number} / Line # #{cil.line_number} must have a Vendor-MID combination on the approved first-sale list."
    end
  end

  def invalid_first_sale_data? line
    line.value_appraisal_method.try(:upcase) != "F" || line.contract_amount.to_f == 0
  end

  def query entry_id, cust_number
    qry = <<-SQL
            SELECT cil.id, UPPER(cil.mid) AS "inv_mid", UPPER(vend.system_code) AS "vendor", UPPER(fact.mid) AS "ord_mid"
            FROM entries e
              INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
              INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
              INNER JOIN orders o ON o.order_number = IF(? = '#{MAURICES_CUST_NUM}', CONCAT('ASCENA-MAU-', cil.po_number), CONCAT("ASCENA-", cil.product_line, "-", cil.po_number))
              LEFT OUTER JOIN companies vend ON vend.id = o.vendor_id
              LEFT OUTER JOIN companies fact ON fact.id = o.factory_id
            WHERE e.id = ?
            ORDER BY cil.id
          SQL
    ActiveRecord::Base.sanitize_sql_array([qry, cust_number, entry_id])
  end

  def results_by_inv_ln qry_results
    qry_results.map{ |r| [r['id'], {mid_vend: "#{r['inv_mid']}-#{r['vendor']}", inv_mid: r['inv_mid'], ord_mid: r['ord_mid']}] }.to_h
  end

  def upcase_hash_keys hsh
    hsh.map { |k, v| [k.upcase, v] }.to_h
  end

  def filed_after_fs_start? filed_date, line_id, xref_hsh, qry_results
    mid_vend = qry_results[line_id][:mid_vend]
    if xref_hsh.keys.include? mid_vend
      filed_date > Date.parse(xref_hsh[mid_vend])
    else
      nil
    end
  end

end; end; end; end
