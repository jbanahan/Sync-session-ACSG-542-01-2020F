module OpenChain
  module Report
    class ShoesForCrewsEntryBreakdown
      def self.run_report run_by, settings={}
        wb = Spreadsheet::Workbook.new
        sheet = wb.create_worksheet :name=>"Entry Breakdown"

        row_cursor = 1
        bill_columns = []
        entries = Entry.where(:customer_number=>"SHOES").where("export_date > '2012-01-01'").order("export_date ASC")
        entries.each do |e|
          charge_totals = {}
          e.broker_invoice_lines.each do |line|
            cd = line.charge_description
            bill_columns << cd unless bill_columns.include?(cd)
            val = charge_totals[cd]
            val = BigDecimal("0.00") unless val
            val = val.add(line.charge_amount, 2)
            charge_totals[cd] = val
          end

          row = sheet.row(row_cursor)
          row.push "VFI"
          row.push val(e, :ent_carrier_code, run_by)
          row.push val(e, :ent_export_date, run_by)
          row.push val(e, :ent_mbols, run_by)
          row.push val(e, :ent_container_nums, run_by)
          row.push val(e, :ent_vendor_names, run_by)
          row.push val(e, :ent_lading_port_name, run_by)
          row.push val(e, :ent_ult_con_name, run_by)
          row.push "#{val(e, :ent_consignee_address_1, run_by)} #{val(e, :ent_consignee_address_2, run_by)}"
          row.push val(e, :ent_consignee_city, run_by)
          row.push val(e, :ent_consignee_state, run_by)
          row.push val(e, :ent_unlading_port_name, run_by)
          row.push val(e, :ent_gross_weight, run_by)
          row.push val(e, :ent_container_sizes, run_by)
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
        row.push "Provider"
        row.push "Carrier Code"
        row.push "Export Date"
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

        t = Tempfile.new(['shoes', '.xls'])
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
