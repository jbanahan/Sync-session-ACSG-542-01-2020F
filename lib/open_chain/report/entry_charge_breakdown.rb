module OpenChain
  module Report
    class EntryChargeBreakdown
      def self.run_report run_by, settings={}
        customer_numbers = settings['customer_numbers']
        start_at = settings['start_at']
        end_at = settings['end_at']
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Entry Breakdown"

        row_cursor = 1
        bill_columns = []
        broker_invoices = BrokerInvoice.joins(:entry).where("entries.customer_number IN (?)",customer_numbers).where("broker_invoices.invoice_date BETWEEN ? AND ?",start_at,end_at)
        broker_invoices.each do |bi|
          e = bi.entry
          charge_totals = {}
          bi.broker_invoice_lines.each do |line|
            cd = line.charge_description
            bill_columns << cd unless bill_columns.include?(cd)
            val = charge_totals[cd]
            val = BigDecimal("0.00") unless val
            val = val.add(line.charge_amount,2)
            charge_totals[cd] = val
          end

          row = sheet.row(row_cursor)
          row.push Spreadsheet::Link.new(e.view_url,val(e,:ent_entry_num,run_by))
          row.push "#{e.broker_reference}#{bi.suffix}"
          row.push val(bi,:bi_invoice_date,run_by)
          row.push val(bi,:bi_invoice_total,run_by)
          row.push val(e,:ent_carrier_code,run_by)
          row.push val(e,:ent_export_date,run_by)
          row.push val(e,:ent_transport_mode_code,run_by)
          row.push val(e,:ent_mbols,run_by)
          row.push val(e,:ent_container_nums,run_by)
          row.push val(e,:ent_vendor_names,run_by)
          row.push val(e,:ent_lading_port_name,run_by)
          row.push val(e,:ent_ult_con_name,run_by)
          row.push "#{val(e,:ent_consignee_address_1,run_by)} #{val(e,:ent_consignee_address_2,run_by)}"
          row.push val(e,:ent_consignee_city,run_by)
          row.push val(e,:ent_consignee_state,run_by)
          row.push val(e,:ent_unlading_port_name,run_by)
          row.push val(e,:ent_gross_weight,run_by)
          row.push val(e,:ent_container_sizes,run_by)
          bill_columns.each do |cd|
            if charge_totals[cd]
              row.push << charge_totals[cd].to_f
            else
              row.push ""
            end
          end
          row_cursor += 1
        end

        row = sheet.row(0)
        row.push "Entry Number"
        row.push "Invoice Number"
        row.push "Invoice Date"
        row.push "Invoice Total"
        row.push "Carrier Code"
        row.push "Export Date"
        row.push "Mode of Transport"
        row.push "Bill of Lading"
        row.push "Container(s)"
        row.push "Vendor"
        row.push "Port Lading"
        row.push "Consignee Name"
        row.push "Consignee Address"
        row.push "Consignee City"
        row.push "Consignee State"
        row.push "Port Unlading"
        row.push "Gross Weight"
        row.push "Container Size(s)"
        bill_columns.each {|cd| row.push cd}

        t = Tempfile.new(['entry_charge_breakdown','.xls'])
        wb.write t.path
        t

      end
      private
      def self.val obj, uid, run_by
        ModelField.find_by_uid(uid).process_export(obj, run_by)
      end
    end
  end
end
