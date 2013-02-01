class CustomReportBillingStatementByPo < CustomReport
  def self.template_name
    "Billing Statement By PO"
  end

  def self.description
    "Shows Broker Invoices with invoice amounts prorated across the number of PO's on the invoice."
  end

  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values
  end

  def self.criterion_fields_available user
    column_fields_available user
  end

  def self.can_view? user
    user.view_broker_invoices?
  end

  def run user, row_limit = nil
    raise "User #{user.email} does not have permission to view invoices and cannot run the #{CustomReportBillingStatementByPo.template_name} report." unless user.view_broker_invoices?

    search_cols = self.search_columns.order("rank ASC")
    invoices = BrokerInvoice.includes(:entry)
    self.search_criterions.each {|sc| invoices = sc.apply(invoices)}
    invoices = BrokerInvoice.search_secure user, invoices
    invoices = invoices.limit(row_limit) if row_limit

    row = 1
    col = 0
    if invoices.empty?
      write row, col, "No data was returned for this report."
      row += 1
    end

    invoices.each do |inv|
      entry = inv.entry
      po_numbers = split_po_numbers entry
      inv_amount = ((inv.invoice_total || BigDecimal.new("0")) / BigDecimal.new(po_numbers.length)).round(2)
      po_numbers.each do |po|
        col = 0
        cols = []

        if self.include_links?
          write_hyperlink row, col, entry.view_url, "Web View"
          col += 1
        end

        cols << entry.broker_reference + inv.suffix
        cols << inv.invoice_date
        cols << inv_amount
        cols << po

        search_cols.each do |c|
          cols << c.model_field.process_export(inv, user)
        end
        
        write_columns row, col, cols
        row += 1
      end
    end    

    col = 0
    heading_row 0
    if self.include_links?
      write 0, col, "Web Links"
      col += 1
    end

    write_columns 0, col, (["Invoice Number", "Invoice Date", "Invoice Total", "PO Number"] \
        + search_cols.collect {|c| c.model_field.label})
  end

  private
  def split_po_numbers entry 
    # split returns a 0-length array on a blank string..hence the space
    po_numbers = (entry.po_numbers.nil? || entry.po_numbers.length == 0) ? " " : entry.po_numbers
    po_numbers.split("\n").collect! {|x| x.strip}
  end
end
