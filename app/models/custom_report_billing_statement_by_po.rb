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
    invoices = BrokerInvoice.select("distinct invoices.*").includes(:entry)
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
      invoice_number = inv.invoice_number
      entry = inv.entry
      if invoice_number.blank?
        invoice_number = entry.broker_reference
        invoice_number << inv.suffix unless inv.suffix.blank?
      end
      po_numbers = split_po_numbers entry
      
      # This invoice amount stuff is there to handle the case where, due to rounding the prorated amount you may
      # be left with the need to tack on an extra penny on the last line (ie. 100 / 3 lines = 33.33, 33.33, 33.34)
      remaining_invoice_amount = inv.invoice_total || BigDecimal.new("0")
      even_split_amount = (remaining_invoice_amount / BigDecimal.new(po_numbers.length)).round(2, BigDecimal::ROUND_DOWN)
      
      po_numbers.each_with_index do |po, i|
        col = 0
        cols = []

        if self.include_links?
          write_hyperlink row, col, entry.view_url, "Web View"
          col += 1
        end

        po_value = BigDecimal.new("0")
        if i < (po_numbers.length - 1) 
          po_value = even_split_amount
          remaining_invoice_amount -= even_split_amount
        else 
          po_value = remaining_invoice_amount
        end

        cols << invoice_number 
        cols << inv.invoice_date
        cols << po_value
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

    write_headers 0, (["Invoice Number", "Invoice Date", "Invoice Total", "PO Number"] + search_cols), user
  end

  private
  def split_po_numbers entry 
    # split returns a 0-length array on a blank string..hence the space
    po_numbers = (entry.po_numbers.nil? || entry.po_numbers.length == 0) ? " " : entry.po_numbers
    po_numbers.split("\n").collect! {|x| x.strip}
  end
end
