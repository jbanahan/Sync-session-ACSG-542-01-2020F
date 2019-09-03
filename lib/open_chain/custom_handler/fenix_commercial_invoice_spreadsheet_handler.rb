require 'open_chain/xl_client'
require 'open_chain/custom_handler/fenix_nd_invoice_generator'
require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler
  class FenixCommercialInvoiceSpreadsheetHandler
    include ActionView::Helpers::NumberHelper
    include OpenChain::CustomHandler::CustomFileCsvExcelParser

    def initialize custom_file
      @custom_file = custom_file
    end

    # Required for custom file processing
    def process user
      errors = []
      begin
        errors = parse @custom_file
      rescue
        errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
        raise 
      ensure
        body = "Fenix Invoice File '#{@custom_file.attached_file_name}' has finished processing."
        subject = "Fenix Invoice File Processing Completed"
        unless errors.blank?
          body += "\n\n#{errors.join("\n")}"
          subject += " With Errors"
        end
       
        user.messages.create(:subject=>subject, :body=>body)
      end
      nil
    end

    def can_view?(user)
      user.company.master?
    end

    def parse custom_file, suppress_fenix_send = false
      errors = []
      invoices_to_send = []
      invoices = extract_invoices custom_file
      invoices.each do |invoice_number, rows|
        begin
          invoice = parse_header rows[0]
          parse_details invoice, rows
          invoice.save!
          invoices_to_send << invoice unless suppress_fenix_send
        rescue => e
          errors << "Failed to process Invoice Number '#{invoice_number}' due to the following error: '#{e.message}'."
        end
      end

      invoices_to_send.each do |invoice|
        OpenChain::CustomHandler::FenixNdInvoiceGenerator.generate invoice.id
      end

      errors
    end

    def parse_header row
      if respond_to?(:prep_header_row)
        row = prep_header_row(row)
      end
      invoice = find_invoice text_value(row[0]), text_value(row[1])

      invoice.invoice_date = date_value row[2]
      invoice.country_origin_code = text_value row[3]
      invoice.currency = 'CAD'
      
      invoice
    end

    def parse_details invoice, rows
      rows.each do |row|
        if respond_to? :prep_line_row
          row = prep_line_row(row)
        end

        detail = invoice.commercial_invoice_lines.build

        detail.part_number = text_value row[4]
        detail.country_origin_code = text_value row[5]
        detail.quantity = decimal_value(row[8])
        detail.unit_price = decimal_value(row[9])
        detail.po_number = text_value row[10]
        detail.customer_reference = text_value row[12]

        tariff = detail.commercial_invoice_tariffs.build
        tariff.hts_code = text_value row[6]
        if tariff.hts_code.respond_to? :gsub
          tariff.hts_code.gsub!(".", "")
        end

        tariff.tariff_description = text_value row[7]
        tariff.tariff_provision = text_value row[11]
      end
    end

    protected 

      def extract_invoices custom_file
        invoice_data = {}

        # We allow multiple invoices per file, so we need to track the invoice number
        # read on the previous line and if it changed then start on a new invoice number.
        # Blank lines between data sets can also be used to denote new invoices.
        previous_invoice_number = nil
        current_invoice_rows = []
        row_number = 0
        foreach(custom_file) do |row|
          #skip the first line if it's the column headings
          next if (row_number +=1) == 1 && has_header_line?

          blank = blank_row? row
          invoice_number = parse_invoice_number_from_row row

          # If we hit a blank row and we have accumulated invoice data
          # Or if we have a new invoice number we'll store off the existing data and 
          # shift to a new one
          if (blank && current_invoice_rows.length > 0) || (!previous_invoice_number.nil? && previous_invoice_number != invoice_number) 
            invoice_data[previous_invoice_number] = current_invoice_rows
            current_invoice_rows = []
            previous_invoice_number = (blank ? nil : invoice_number)
          elsif !blank && previous_invoice_number.blank?
            previous_invoice_number = invoice_number
          end

          next if blank
          current_invoice_rows << row
        end

        unless current_invoice_rows.blank?
          invoice_data[previous_invoice_number] = current_invoice_rows
        end

        invoice_data
      end

      def has_header_line?
        true
      end

      def parse_invoice_number_from_row row
        row[1]
      end

      def find_invoice fenix_importer, invoice_number
        # Verify the customer number is valid (should be the tax id)
        importer = Company.importers.with_fenix_number(fenix_importer).first unless fenix_importer.blank?
        raise "No Fenix Importer associated with the Tax ID '#{fenix_importer}'." unless importer

        invoice = nil
        # We can't really look up an existing invoice if the invoice # was blank.
        # We support blank invoices Since we do allow them to upload invoices with no number whereby we just
        # send an autogenerated value to Fenix.
        unless invoice_number.blank?
          invoice = CommercialInvoice.where(importer_id: importer.id, invoice_number: invoice_number).order("commercial_invoices.updated_at DESC").first

          # Clear out any invoice lines since we're rebuilding from scratch
          if invoice
            invoice.commercial_invoice_lines.destroy_all
          end
        end

        unless invoice
          invoice = CommercialInvoice.new importer: importer, invoice_number: invoice_number
        end

        invoice
      end

  end
end; end;