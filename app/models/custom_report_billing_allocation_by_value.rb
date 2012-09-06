class CustomReportBillingAllocationByValue < CustomReport

  def self.template_name
    "Invoice Allocation By Invoice Value"
  end

  def self.description
    "Shows Broker Invoices with each charge allocated at the commercial invoice line level by commercial invoice value."
  end

  def self.column_fields_available user
    CoreModule::ENTRY.model_fields_including_children(user).values
  end

  def self.criterion_fields_available user
    CoreModule::BROKER_INVOICE.model_fields(user).values
  end

  def self.can_view? user
    user.view_broker_invoices?
  end

  def run run_by, row_limit = nil
    row_cursor = 0
    col_cursor = 0
    self.search_columns.each do |sc|
      write row_cursor, col_cursor, sc.model_field.label
      col_cursor += 1
    end
    hard_code_fields = [:bi_brok_ref,:bi_invoice_date,:bi_invoice_total].collect {|x| ModelField.find_by_uid(x)}
    hard_code_fields.each do |mf|
      write row_cursor, col_cursor, mf.label
      col_cursor += 1
    end
    charge_start_column = col_cursor
    
    col_cursor = 0
    row_cursor = 1
    
    bill_columns = []
    invoices = BrokerInvoice.where("1=1").includes(:entry=>[:commercial_invoice_lines])
    invoices = BrokerInvoice.search_secure run_by, invoices
    search_criterions.each {|sc| invoices = sc.apply(invoices)}
    invoices.each do |bi|
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
      entry = bi.entry
      ci_lines = entry.commercial_invoice_lines
      total_value = entry.commercial_invoice_lines.inject(BigDecimal.new(0,5)) {|r,cil| cil.value.blank? ? r : r+BigDecimal.new(cil.value,5)}
      use_hts_value = false
      if total_value == 0
        use_hts_value = true
        total_value = entry.commercial_invoice_lines.inject(BigDecimal.new(0,5)) do |r,cil|
          add = 0
          t = cil.commercial_invoice_tariffs.first
          if !t.blank? && !t.entered_value.blank?
            add = t.entered_value
          end
          r + BigDecimal.new(add,5)
        end
      end
      running_totals = {} 
      line_count = ci_lines.size
      ci_lines.each_with_index do |line,i|
        break if row_limit && row_cursor>row_limit
        line_value = line.value
        line_value = line.commercial_invoice_tariffs.first.nil? ? 0 : line.commercial_invoice_tariffs.first.entered_value if use_hts_value
        if self.include_links?
          write_hyperlink row_cursor, col_cursor, entry.view_url,"Web View"
          col_cursor += 1
        end
        self.search_columns.each do |sc|
          mf = sc.model_field
          obj_to_proc = nil
          case mf.core_module
          when CoreModule::ENTRY
            obj_to_proc = entry
          when CoreModule::COMMERCIAL_INVOICE
            obj_to_proc = line.commercial_invoice
          when CoreModule::COMMERCIAL_INVOICE_LINE
            obj_to_proc = line
          when CoreModule::COMMERCIAL_INVOICE_TARIFF
            obj_to_proc = line.commercial_invoice_tariffs.first
          end
          write row_cursor, col_cursor, (obj_to_proc ? mf.process_export(obj_to_proc,run_by) : "")
          col_cursor += 1
        end
        write row_cursor, col_cursor, ModelField.find_by_uid(:ent_brok_ref).process_export(entry,run_by)
        col_cursor += 1
        write row_cursor, col_cursor, ModelField.find_by_uid(:bi_invoice_date).process_export(bi,run_by)
        col_cursor += 1
        write row_cursor, col_cursor, ModelField.find_by_uid(:bi_invoice_total).process_export(bi,run_by)
        col_cursor += 1
          
        bill_columns.each do |cd|
          content = ""
          if charge_totals[cd]
            content = ( (charge_totals[cd]/total_value)*line_value ).round(2)
            running_totals[cd] ||= BigDecimal.new(0,2)
            running_totals[cd] = running_totals[cd] + content
            if i== (line_count-1)
              diff = charge_totals[cd]-running_totals[cd]
              content = content + diff
            end
          else
            content = ""
          end
          write row_cursor, col_cursor, content
          col_cursor += 1
        end

        row_cursor += 1
        col_cursor = 0
      end
    end

    col_cursor = charge_start_column
    bill_columns.each do |label|
      write 0, col_cursor, label
      col_cursor += 1
    end
    heading_row 0
  end
end
