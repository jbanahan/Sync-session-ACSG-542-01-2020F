require 'open_chain/url_support'

module CustomReportEntryInvoiceBreakdownSupport
  extend OpenChain::UrlSupport

  def process run_by, row_limit, hide_repeating_headers
    raise "User #{run_by.email} does not have permission to view invoices and cannot run the #{CustomReportEntryInvoiceBreakdown.template_name} report." unless run_by.view_broker_invoices?
    search_cols = self.search_columns.order("rank ASC")
    if hide_repeating_headers
      search_col_mods = {}
      search_cols.each { |sc| search_col_mods[sc.model_field_uid] = table_from_mf(sc.model_field_uid) } # HACK (see below)
    end
    invoices = BrokerInvoice.select("DISTINCT broker_invoices.*")
    self.search_criterions.each {|sc| invoices = sc.apply invoices}
    invoices = BrokerInvoice.search_secure run_by, invoices
    invoices = invoices.limit(row_limit) if row_limit

    row_cursor = 1
    col_cursor = 0
    if invoices.empty?
      write row_cursor, col_cursor, "No data was returned for this report."
      row_cursor += 1
    end
    bill_columns = []
    previous_entry = nil
    invoices.each do |bi|
      current_entry = bi.entry
      if current_entry == previous_entry
        repeating_header = true
      else
        repeating_header = false
        previous_entry = current_entry
      end
      charge_totals = {}
      bi.broker_invoice_lines.each do |line|
        next if line.charge_type == "D"
        cd = line.charge_description
        cd = "ISF" if cd.starts_with?("ISF")
        bill_columns << cd unless bill_columns.include?(cd)
        val = charge_totals[cd]
        val = BigDecimal("0.00") unless val
        val = val + line.charge_amount
        charge_totals[cd] = val
      end
      if self.include_links?
        if bi.entry.present?
          write_hyperlink row_cursor, col_cursor, bi.entry.view_url, "Web View"
        end
        col_cursor += 1
      end
      if self.include_rule_links?
        if bi.entry.present?
          write_hyperlink row_cursor, col_cursor, validation_results_url(obj: bi.entry), "Web View"
        end
        col_cursor += 1
      end
      search_cols.each do |col|
        unless hide_repeating_headers && repeating_header && search_col_mods[col.model_field_uid] == 'entries'
          content = col.model_field.process_export(bi, run_by)
          write row_cursor, col_cursor, content
        end
        col_cursor += 1
      end
      bill_columns.each do |cd|
        if charge_totals[cd]
          content = charge_totals[cd]
        else
          content = ""
        end
        write row_cursor, col_cursor, content
        col_cursor += 1
      end
      col_cursor = 0
      row_cursor += 1
    end

    # write headings
    header = []

    search_cols.each do |col|
      header << col
    end
    bill_columns.each do |cd|
      header << cd
    end

    write_headers 0, header, run_by
  end

  # HACK - Uses an MF's qualified field name to identify the table the field points to
  def table_from_mf mf_uid
    ModelField.find_by_uid(mf_uid).qualified_field_name.scan(/from\s\w+/i)[0].try(:split, " ").try(:last)
  end
end

