class CustomReportEntryInvoiceBreakdown < CustomReport
  #display name for report
  def self.template_name
    "Entry Summary Billing Breakdown"
  end

  #long description of report purpose / structure
  def self.description
    "Shows Broker Invoices with entry header information and each charge in its own column."
  end

  #ModelFields available to be included on report as columns
  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values
  end


  #ModelFields available to be used as SearchCriterions
  def self.criterion_fields_available user
    column_fields_available user
  end

  #can this user run the report
  def self.can_view? user
    user.view_broker_invoices? 
  end

  def run run_by, row_limit = nil
    raise "User #{run_by.email} does not have permission to view invoices and cannot run the #{CustomReportEntryInvoiceBreakdown.template_name} report." unless run_by.view_broker_invoices?
    search_cols = self.search_columns.order("rank ASC")
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
    invoices.each do |bi|
      e = bi.entry
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
        write_hyperlink row_cursor, col_cursor, bi.entry.view_url,"Web View"
        col_cursor += 1
      end
      search_cols.each do |col| 
        content = col.model_field.process_export(bi,run_by) 
        write row_cursor, col_cursor, content
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

    #write headings
    header = []

    if self.include_links?
      header << "Web Links"
    end
    search_cols.each do |col| 
      header << col
    end
    bill_columns.each do |cd|
      header << cd
    end

    write_headers 0, header, run_by
  end

end
