require 'open_chain/report/report_helper'

module OpenChain; module Report; class HmCanadaDrawbackReport
  include OpenChain::Report::ReportHelper

  HM_CANADA_DRAWBACK_USERS ||= 'hm_canada_drawback_report'

  def self.permission? user
    user.in_group?(Group.use_system_group(HM_CANADA_DRAWBACK_USERS, name:"H&M Canada Drawback Report", description:"Users permitted to run the H&M Canada Drawback Report."))
  end

  def self.run_report run_by, settings
    self.new.generate_and_send_report run_by, settings
  end

  def generate_and_send_report run_by, settings
    start_date = sanitize_date_string settings['start_date'], run_by.time_zone
    end_date = sanitize_date_string settings['end_date'], run_by.time_zone

    workbook = nil
    distribute_reads do
      workbook = generate_report start_date, end_date
    end

    file_name = "HM_Canada_Drawback_Report_#{start_date}_#{end_date}.xlsx"
    workbook_to_tempfile(workbook, "HM Canada Drawback Report", file_name: "#{file_name}")
  end

  private
    def generate_report start_date, end_date
      wb = XlsxBuilder.new
      assign_styles wb

      sheet = wb.create_sheet "Data"
      wb.add_header_row sheet, make_headers

      returns_entries = Entry.where(customer_number:'HENNE', release_date:start_date..end_date)
      returns_entries.find_each(batch_size:50) do |returns_entry|
        returns_entry.commercial_invoices.each do |returns_invoice|
          # VFI Track adds a suffix to the invoice number when it processes the Fenix file: lengthy invoices
          # are split into multiple containing 999 or fewer lines for CBSA compliance.  The I2 drawback files
          # aren't aware of this and have only the original, unhyphened invoice numbers.
          returns_invoice_number = returns_invoice.invoice_number.split('-').first

          returns_invoice_line_hash = returns_invoice.commercial_invoice_lines.group_by { |i| i.part_number }
          returns_invoice_line_hash.each do |returns_part_number, returns_invoice_line_arr|
            returns_invoice_line = returns_invoice_line_arr[0]

            # Look for a matching I2 export line.  Invoice line part number is a 7-character part number/style.
            # The I2 part number value is really a SKU that begins with the part number, but contains additional
            # information.  Because of that, we must use like-matching.  Between invoice and part numbers, we
            # have a unique I2 file match most of the time, but it's possible multiple records will match.
            returns_i2_matches = HmI2DrawbackLine.where(invoice_number:returns_invoice_number, shipment_type:"returns").where("part_number like ?", "#{returns_part_number}%")
            next unless returns_i2_matches.length > 0

            # Attempt to create a report row for each unique customer order reference within the returns I2
            # matches on part and invoice number.  We're probably talking about only one in most cases.
            returns_i2_hash_by_order_ref = returns_i2_matches.group_by { |i| i.customer_order_reference }
            returns_i2_hash_by_order_ref.each_value do |matches|
              returns_i2_match = matches[0]
              # Look for the matching export I2 drawback line by (customer) PO number and part number.  If more
              # than one matches are found, just use the first.
              export_i2_match = HmI2DrawbackLine.where(customer_order_reference:returns_i2_match.customer_order_reference, shipment_type:"export", part_number:returns_i2_match.part_number).first
              next unless export_i2_match

              # Now connect up the export invoice.  The invoice number here is different than the invoice number
              # on the returns side, hence the convoluted connection.  Note that the invoice number in the
              # commercial invoice may contain a numeric suffix that is not present in the I2 data (see above).
              # The part numbers will be 7 char max, versus the longer SKUs used in the I2 data.
              export_invoice_line = CommercialInvoiceLine.joins(:commercial_invoice, {commercial_invoice: :entry}).where(part_number: returns_part_number[0..6]).where(entries: { customer_number:"HMCAD" }).where("commercial_invoices.invoice_number like ?", "#{export_i2_match.invoice_number}%").first
              next unless export_invoice_line

              row = []
              # Order ref should be the same for both returns and export.
              row << returns_i2_match.customer_order_reference
              # Returns/US-entry-related fields.
              row << returns_entry.entry_number
              row << returns_i2_match.part_number
              row << returns_i2_match.part_description
              row << returns_i2_match.quantity
              row << returns_i2_match.shipment_date
              # Intentionally blank.  Subheader Number "does not exist for US".
              row << nil
              row << returns_invoice_line.customs_line_number
              row << returns_invoice_line.unit_price
              # Export/CA-entry-related fields.
              row << export_invoice_line.entry.entry_number
              row << export_invoice_line.part_number
              row << export_invoice_line.commercial_invoice_tariffs[0]&.tariff_description
              row << export_invoice_line.quantity
              row << export_invoice_line.entry.import_date
              row << export_invoice_line.subheader_number
              row << export_invoice_line.customs_line_number
              row << export_invoice_line.unit_price

              wb.add_body_row(sheet, row, styles:(Array.new(4, :none) + [:number, :date, :number, :number, :currency] + Array.new(3, :none) + [:number, :date, :number, :number, :currency]))
            end
          end
        end
      end

      wb.set_column_widths sheet, 20, 22, 20, 20, 16, 16, 20, 16, 16, 22, 20, 20, 16, 16, 20, 16, 16

      wb
    end

    def assign_styles wb
      wb.create_style :none, {}
      wb.create_style(:date, {format_code: "YYYY-MM-DD"})
      wb.create_style(:currency, {format_code: "$#,##0.00"})
      wb.create_style(:number, {format_code: "#,##0"})
    end

    def make_headers
      ["HM Order Number", "US Transaction Number", "Part Number", "Description", "Quantity", "Export Date", "Subheader Number", "Line Number", "Unit Price", "CDN Transaction Number", "Part Number", "Description", "Quantity", "Import Date", "Subheader Number", "Line Number", "Unit Price"]
    end

end; end; end