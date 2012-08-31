class CustomReportEntryInvoiceBreakdown < CustomReport
  #display name for report
  def self.template_name
    "Entry Summary Billing Breakdown"
  end

  #long description of report purpose / structure
  def self.description
    "Shows Broker Invoices with entry header information and each charge in it's own column."
  end

  #ModelFields available to be included on report as columns
  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields.values.collect {|mf| mf if mf.can_view?(user)}.compact!
  end

  #ModelFields available to be used as SearchCriterions
  def self.criterion_fields_available user
    column_fields_available user
  end

  #can this user run the report
  def self.can_view? user
    user.view_broker_invoices? 
  end

  def run run_by
    raise "User #{run_by.email} does not have permission to view invoices and cannot run the #{CustomReportEntryInvoiceBreakdown.template_name} report." unless run_by.view_broker_invoices?
    search_cols = self.search_columns.order("rank ASC")
    invoices = BrokerInvoice.select("DISTINCT broker_invoices.*")
    self.search_criterions.each {|sc| invoices = sc.apply invoices}
    invoices = BrokerInvoice.search_secure run_by, invoices
    wb = Spreadsheet::Workbook.new
    sheet = wb.create_worksheet :name=>"Entry Breakdown"

    row_cursor = 1
    col_cursor = 0
    if invoices.empty?
      sheet.row(row_cursor)[col_cursor] = "No data was returned for this report."
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
      row = sheet.row(row_cursor)
      if self.include_links?
        row[col_cursor] = Spreadsheet::Link.new(bi.entry.view_url,"Web View")
        col_cursor += 1
      end
      search_cols.each do |col| 
        content = col.model_field.process_export(bi,run_by) 
        content = content.to_s.to_f if content.is_a?(BigDecimal)
        row[col_cursor] = content
        update_column_width sheet, col_cursor, (content.is_a?(Date) ? 10 : content.to_s.size)
        col_cursor += 1
      end
      bill_columns.each do |cd|
        if charge_totals[cd]
          content = charge_totals[cd].to_s.to_f
        else
          content = ""
        end
        row[col_cursor] = content
        update_column_width sheet, col_cursor, content.to_s.size
        col_cursor += 1
      end
      col_cursor = 0
      row_cursor += 1
    end

    #write headings
    row = sheet.row(0)
    col_cursor = 0
    row.default_format = XlsMaker::HEADER_FORMAT
    if self.include_links?
      row[col_cursor] = "Web Links"
      update_column_width sheet, col_cursor, 9
      col_cursor += 1
    end
    search_cols.each do |col| 
      content = col.model_field.label 
      row[col_cursor] = content
      update_column_width sheet, col_cursor, content.size
      col_cursor += 1
    end
    bill_columns.each do |cd| 
      row[col_cursor] = cd
      update_column_width sheet, col_cursor, cd.size
      col_cursor += 1
    end

    #write output file
    t = Tempfile.new(['entry_charge_breakdown','.xls'])
    wb.write t.path
    t
  end

end
