require 'open_chain/custom_handler/custom_file_csv_excel_parser'

# Converts one inbound spreadsheet to another spreadsheet, emailed outbound, by marrying the former with entry data.
# Does not update any entry content in the database.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberAllportBillingFileParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  MONEY_FORMAT ||= XlsMaker.create_format "Money", :number_format => '$#,##0.00'

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS', '.XLSX'].include? File.extname(filename.upcase)
  end

  def can_view? user
    user.company.broker? && MasterSetup.get.custom_feature?('Lumber ACS Billing Validation')
  end

  def process user
    process_file @custom_file, user
    nil
  end

  private
    def process_file custom_file, user
      errors = []
      begin
        inbound_file_hash = condense_inbound_file_by_entry custom_file, errors

        outbound_row_number = 1
        wb, sheet = XlsMaker.create_workbook_and_sheet "Results", ["Customer Name", "Customer Number", "Broker Reference", "Entry Number", "BOL Date", "Export Date", "Entry Filed Date", "Release Date", "Master Bills", "House Bills", "Container Numbers", "Container Sizes", "Total Broker Invoice", "Container Count", "Cost", "Links"]
        total_cost = 0
        inbound_file_hash.each_value do |entry_row|
          begin
            add_row_to_sheet entry_row.entry, entry_row.total_management_fee, sheet, outbound_row_number
            outbound_row_number += 1
            total_cost += entry_row.total_management_fee
          rescue => e
            errors << "Row #{entry_row.row_number}: Failed to process line due to the following error: '#{e.message}'"
          end
        end

        # Add a totals row.  This is blank except for the Cost column.
        if total_cost > 0
          output_line = []
          output_line[14] = total_cost
          XlsMaker.add_body_row sheet, outbound_row_number, output_line
          sheet.row(outbound_row_number).set_format(14, MONEY_FORMAT)
        end

        XlsMaker.set_column_widths sheet, [20, 20, 20, 20, 16, 15, 16, 16, 20, 20, 20, 20, 18, 15, 12, 10]

        generate_email user, custom_file, wb, errors
      rescue MalformedAllportBillingFileError => e
        generate_malformed_file_error_email user, custom_file
      end

      nil
    end

    # Generates a hash that condenses a container-level file into entry-level data for an outbound feed.  This process
    # involves an entry look-up, which could log errors.
    def condense_inbound_file_by_entry custom_file, errors
      inbound_row_number = 1
      inbound_file_hash = {}
      column_headings_found = false

      # Source file is an Excel spreadsheet.  We're dealing with it remotely, on a server equipped to deal with Excel crud.
      # Here, thanks to the handy 'foreach' method below, the parser doesn't need to be aware of the original data format.
      foreach(custom_file) do |row|
        # The first 15+ lines of the file need to be skipped.  It's a multi-line header.  Unfortunately, the number of
        # lines in the header varies, forcing us to look for a specific text value in the first column.  If that turns
        # out not to be consistent too...
        if !column_headings_found && !blank_row?(row) && row[0] == "Purchase Order" && row[1] == "BL/AWB/PRO"
          column_headings_found = true

        # Once the column headings line has been found, subsequent lines can be processed.  Skip blank lines and lines
        # that don't contain a PO number, BOL or container: this latter restriction eliminates the totals row at the
        # bottom of the document, which should not be processed.  We can't exclude blank lines via 'foreach' because
        # a line number is included in error messages, and stripping blanks out before the line counter is established
        # could result in inconsistency, chaos and confusion.
        elsif column_headings_found && !blank_row?(row) && (row[0].present? || row[1].present? || row[2].present?)
          bill_of_lading = row[1]
          container_number = row[2]
          entry = find_matching_entry bill_of_lading, container_number, inbound_row_number, errors
          if entry
            data = inbound_file_hash[entry.id]
            if data.nil?
              data = CondensedAllportData.new
              data.entry = entry
              data.row_number = inbound_row_number
              data.total_management_fee = 0
              inbound_file_hash[entry.id] = data
            end
            data.total_management_fee = data.total_management_fee + row[6].to_f
          end
        end

        inbound_row_number += 1
      end

      if !column_headings_found
        raise MalformedAllportBillingFileError.new("Column headings not found")
      end

      inbound_file_hash
    end

    class CondensedAllportData
      attr_accessor :entry, :row_number, :total_management_fee
    end

    def add_row_to_sheet entry, total_management_fee, sheet, outbound_row_number
      output_line = []
      output_line << entry.customer_name
      output_line << entry.customer_number
      output_line << entry.broker_reference
      output_line << entry.entry_number
      output_line << entry.bol_received_date
      output_line << entry.export_date
      output_line << entry.entry_filed_date
      output_line << entry.release_date
      output_line << entry.split_master_bills_of_lading.join(',')
      output_line << entry.split_house_bills_of_lading.join(',')
      output_line << entry.split_newline_values(entry.container_numbers).join(',')
      output_line << entry.split_newline_values(entry.container_sizes).join(',')
      output_line << entry.broker_invoice_total
      # In the event there aren't any containers, default the container count to 1.  This shouldn't happen.
      output_line << (entry.containers.length > 0 ? entry.containers.length : 1)
      output_line << total_management_fee
      output_line << Spreadsheet::Link.new(entry.excel_url, "Web View")

      XlsMaker.add_body_row sheet, outbound_row_number, output_line
      sheet.row(outbound_row_number).set_format(12, MONEY_FORMAT)
      sheet.row(outbound_row_number).set_format(14, MONEY_FORMAT)
    end

    def find_matching_entry bill_of_lading, container_number, row_number, errors
      matching_entry = nil

      # Find the matching entry by bill of lading, assuming we have one.  This can be a match to either master or house.
      entries = []
      if bill_of_lading
        entries = find_matching_lumber_entries Entry.where("master_bills_of_lading LIKE ? OR house_bills_of_lading LIKE ?", "%#{bill_of_lading}%", "%#{bill_of_lading}%")
      end

      # If multiple BOL-matching rows have been found, try to reduce the number by matching to container number
      # as well.
      if entries.length > 1
        container_matching_entries = []
        entries.each do |current_entry|
          if current_entry.container_numbers.try(:include?, container_number)
            container_matching_entries << current_entry
          end
        end
        if container_matching_entries.length == 1
          entries = container_matching_entries
        else
          errors << "Row #{row_number}: Multiple entry matches found for bill of lading '#{bill_of_lading}': #{get_file_numbers(entries).join(", ")}."
        end
      end

      if entries.length == 1 && entries[0].broker_invoices.length == 0
        # There can be 'skeletal' entries in the system that match on master bill, but are lacking most other data.
        # It was decided to error out on these as well.
        errors << "Row #{row_number}: The only entry with bill of lading '#{bill_of_lading}' has not been billed and cannot be used for matching purposes: #{entries[0].broker_reference}."
      else
        # If a match couldn't be made via bill of lading and we have a container number, try to match on that.
        if entries.length == 0 && container_number
          entries = find_matching_lumber_entries Entry.where("container_numbers LIKE ?", "%#{container_number}%")
          if entries.length > 1
            errors << "Row #{row_number}: Multiple entry matches found for container '#{container_number}': #{get_file_numbers(entries).join(", ")}."
          end
        end

        if entries.length == 1
          matching_entry = entries[0]
        elsif entries.length == 0
          errors << "Row #{row_number}: There were no matching entries for bill of lading '#{bill_of_lading}' or container '#{container_number}'."
        end
      end

      matching_entry
    end

    # Limits all entry lookups to LL Kewill entries released within the last 6 months only.  In mid-2020, this query was
    # amended to also include entries without release dates.  Per Luca De Candia, "we are being pressured to pay the
    # vendor more quickly so we are running the reports a bit sooner."  Entry filed date was incoporated as a backstop.
    # (Luca also specified 6 months should be fine as a filed date limit.)
    def find_matching_lumber_entries base_lookup
      base_lookup.where(customer_number:'LUMBER', source_system:Entry::KEWILL_SOURCE_SYSTEM)
                 .where("release_date >= ? OR release_date IS NULL", (Time.zone.now - 6.months).to_s(:db))
                 .where("entry_filed_date >= ?", (Time.zone.now - 6.months).to_s(:db))
    end

    def get_file_numbers entries
      file_numbers = []
      entries.each do |entry|
        file_numbers << entry.broker_reference
      end
      file_numbers
    end

    def generate_email user, inbound_custom_file, report_workbook, errors
      download_inbound_file_for_email_attachment(inbound_custom_file) do |inbound_file|
        Tempfile.open(["LL_Billing_Report", ".xls"]) do |outbound_file|
          Attachment.add_original_filename_method outbound_file, "Lumber_ACS_billing_report_#{Time.zone.now.strftime("%Y-%m-%d")}.xls"
          report_workbook.write outbound_file
          outbound_file.flush
          outbound_file.rewind

          body_text = "The attached report was generated based on a report uploaded to VFI Track, which is also attached to this email."
          if errors.length > 0
            body_text += "<br><br>Errors encountered:<br>#{errors.join("<br>")}"
          end

          OpenMailer.send_simple_html(user.email, 'Lumber ACS Billing Validation Report', body_text.html_safe, [outbound_file, inbound_file]).deliver_now
        end
      end
    end

    def download_inbound_file_for_email_attachment inbound_custom_file
      Attachment.download_to_tempfile(inbound_custom_file.attached, original_file_name:inbound_custom_file.attached_file_name) do |inbound_file|
        yield inbound_file
      end
    end

    def generate_malformed_file_error_email user, inbound_custom_file
      download_inbound_file_for_email_attachment(inbound_custom_file) do |inbound_file|
        body_text = "This file could not be processed because the column header line could not be found.  In order for that line to be found, the first two column headings must be (exactly) 'Purchase Order' and 'BL/AWB/PRO'.  Please correct and upload the file again."
        OpenMailer.send_simple_html(user.email, 'Malformed Lumber ACS Billing File', body_text.html_safe, [inbound_file]).deliver_now
      end
    end

    class MalformedAllportBillingFileError < StandardError

    end

end; end; end; end