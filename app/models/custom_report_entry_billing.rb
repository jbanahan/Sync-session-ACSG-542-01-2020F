# -*- SkipSchemaAnnotations

class CustomReportEntryBilling < CustomReport
  attr_accessible :include_links, :include_rule_links, :name, :no_time, :type, :user_id

  # display name for report
  def self.template_name
    "Entry Billing"
  end

  # long description of report purpose / structure
  def self.description
    "Shows Broker Invoices with links to Entry."
  end

  # ModelFields available to be included on report as columns
  def self.column_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values + CoreModule::BROKER_INVOICE_LINE.model_fields(user).values
  end


  # ModelFields available to be used as SearchCriterions
  def self.criterion_fields_available user
    column_fields_available user
  end

  # can this user run the report
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

    # write headings
    header = []
    search_cols.each do |col|
      header << col
    end

    write_headers 0, header, run_by

    row_cursor = 0
    col_cursor = 0
    if invoices.empty?
      write row_cursor, col_cursor, "No data was returned for this report."
      row_cursor += 1
    end

    invoices.each do |inv|
      lines = inv.broker_invoice_lines

      if lines.length == 0
        row = []
        search_cols.each do |col|
          mf = col.model_field
          if mf.core_module.klass.is_a?(BrokerInvoice)
            row << mf.process_export(inv, run_by)
          else
            row << nil
          end
        end
        write_data (row_cursor +=1), inv.entry, row
      else
        lines.each do |line|
          row = []
          search_cols.each do |col|
            mf = col.model_field
            if mf.core_module.klass == BrokerInvoiceLine
              row << mf.process_export(line, run_by)
            else
              row << mf.process_export(inv, run_by)
            end
          end
          write_data (row_cursor +=1), inv.entry, row
        end
      end
    end
  end

  private
    def write_data row_cursor, entry, row
      column = 0
      if entry
        if self.include_links?
          write_hyperlink row_cursor, column, entry.view_url, "Web View"
          column += 1
        end

        if self.include_rule_links?
          write_hyperlink row_cursor, column, validation_results_url(obj: entry), "Web View"
          column += 1
        end

      else
        row = []
        row << nil if self.include_links?
        row << nil if self.include_rule_links?
        row.concat row
      end

      write_columns row_cursor, column, row
    end

end
