module OpenChain; module CustomHandler; module Ascena; class ValidationRuleAscenaFirstSale < BusinessValidationRule

  def run_validation entry
    return nil unless entry.entry_filed_date

    # What we need to do here is ensure that every single invoice line on the entry that has an MID-VendorID that 
    # matches one of the MID-VendorIDs in their list (xref'ed type) and has a filed date after the FS start date in 
    # the corresponding xref has first sale data.

    xref = upcase_hash_keys DataCrossReference.hash_for_type(DataCrossReference::ASCE_MID)
    mid_vendors_on_entry = entry_mid_vendors(entry.id)

    errors = []
    air = entry.transport_mode_code.to_s == "40"

    entry.commercial_invoices.each do |i|
      # Skip any envoice that ends with NFS (No Margin for Vendors (?)) or MIN (minimum)
      next if i.invoice_number.to_s.upcase.end_with?("NFS") || i.invoice_number.to_s.upcase.end_with?("MIN")

      i.commercial_invoice_lines.each do |l|
        next if l.mid.blank?

        # Skip if air entry and line has non-dutiable charges
        next if air && l.non_dutiable_amount.to_f > 0
 
        if filed_after_fs_start?(entry.entry_filed_date, l.id, xref, mid_vendors_on_entry) && invalid_first_sale_data?(l)
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must have Value Appraisal Method and Contract Amount set."
        end

        if l.contract_amount.to_f > 0 && l.contract_amount.to_f < l.total_entered_value
          errors << "Invoice # #{i.invoice_number} / Line # #{l.line_number} must have a First Sale Contract Amount greater than the Entered Value."
        end
      end
    end

    errors.length > 0 ? errors.uniq.join("\n") : nil
  end

  def invalid_first_sale_data? line
    line.value_appraisal_method.try(:upcase) != "F" || line.contract_amount.to_f == 0
  end

  def query entry_id
    <<-SQL
      SELECT cil.id, CONCAT(UPPER(cil.mid),"-",UPPER(vend.system_code)) AS mid_vendor
      FROM entries e
        INNER JOIN commercial_invoices ci ON e.id = ci.entry_id
        INNER JOIN commercial_invoice_lines cil ON ci.id = cil.commercial_invoice_id
        INNER JOIN orders o ON o.order_number = CONCAT("ASCENA-", cil.po_number)
        INNER JOIN companies vend ON vend.id = o.vendor_id
      WHERE e.id = #{entry_id}
      ORDER BY cil.id
    SQL
  end

  def entry_mid_vendors entry_id
    out = {}
    res = ActiveRecord::Base.connection.execute query(entry_id)
    res.each { |r| out[r[0]] = r[1] }
    out
  end

  def upcase_hash_keys hsh
    out = {}
    hsh.keys.each { |k| out[k.upcase] = hsh[k] }
    out
  end

  def filed_after_fs_start? filed_date, line_id, xref_hsh, mid_vend_hsh
    mid_vend = mid_vend_hsh[line_id]
    if xref_hsh.keys.include? mid_vend
      filed_date > Date.parse(xref_hsh[mid_vend])
    else
      nil
    end
  end

end; end; end; end