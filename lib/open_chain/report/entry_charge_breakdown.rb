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
            next if line.charge_type == "D"
            cd = line.charge_description
            bill_columns << cd unless bill_columns.include?(cd)
            val = charge_totals[cd]
            val = BigDecimal("0.00") unless val
            val = val + line.charge_amount
            charge_totals[cd] = val
          end

          row = sheet.row(row_cursor)
          row.push val(e,:ent_entry_num,run_by)
          row.push "#{e.broker_reference}#{bi.suffix}"
          row.push val(bi,:bi_invoice_date,run_by)
          row.push bi.invoice_total.nil? ? BigDecimal("0.00").to_s.to_f : BigDecimal(bi.invoice_total,2).to_s.to_f
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
          row.push val(e,:ent_total_duty,run_by)
          row.push val(e,:ent_total_hmf,run_by)
          row.push val(e,:ent_total_mpf,run_by)
          row.push val(e,:ent_cotton_fee,run_by)
          bill_columns.each do |cd|
            if charge_totals[cd]
              row.push << charge_totals[cd].to_s.to_f
            else
              row.push ""
            end
          end
          row.push e.view_url
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
        row.push "Duty"
        row.push "HMF"
        row.push "MPF"
        row.push "Cotton Fees"
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
