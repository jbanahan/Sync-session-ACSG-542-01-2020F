require 'bigdecimal'
require 'tempfile'
require 'csv'

module OpenChain
  module CustomHandler
    class PoloSapInvoiceFileGenerator

      RL_CANADA_TAX_IDS ||= ['806167003RM0001'] # This is ONLY the RL Canada importer, other RL accounts are done by hand for now
      EMAIL_INVOICES_TO ||= ["joanne.pauta@ralphlauren.com", "james.moultray@ralphlauren.com", "dean.mark@ralphlauren.com", "accounting-ca@vandegriftinc.com"]

      def initialize env = :prod, custom_where = nil
        # env == :qa will send the invoices to a "test" directory
        @env = env
        @custom_where = custom_where
      end

      def self.run_schedulable opts = {}
        PoloSapInvoiceFileGenerator.new.find_generate_and_send_invoices
      end

      def find_generate_and_send_invoices 
        Time.use_zone("Eastern Time (US & Canada)") do
          start_time = Time.zone.now
          generate_and_send_invoices start_time, find_broker_invoices
        end
      end

      def find_broker_invoices 
        # We should be fine eager loading everything here since we're doing these week by week.
        # It shouldn't be THAT much data, at least at this point.
        query = BrokerInvoice.select("distinct broker_invoices.*").
                includes([{:entry=>{:commercial_invoices=>:commercial_invoice_lines}}, :broker_invoice_lines]).
                order("broker_invoices.invoice_date ASC")


        if @custom_where
          # Presumably, for the QA case, we're just going to be listing specific invoice #'s
          # Or at least something that limits the invoice output
          query = query.where(@custom_where)
        else
          query = query.where(:entries => {:importer_tax_id => RL_CANADA_TAX_IDS}).
                    where("broker_invoices.invoice_date >= ?", Date.new(2013, 6, 01)).
                    # We need to exclude everything that has already been successfully invoiced
                    where("broker_invoices.id NOT IN ("+
                      "SELECT ejl.exportable_id FROM export_job_links ejl "+
                      "INNER JOIN export_jobs ej ON ejl.export_job_id = ej.id " +
                      "AND ejl.exportable_type = 'BrokerInvoice' AND ej.successful = true " +
                      "AND ej.export_type IN (?) )", [ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE, ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE])
        end

        query.all
      end

      def generate_and_send_invoices start_time, broker_invoices
       # Send them 
        if broker_invoices.length > 0
          files = []
          begin
            invoice_output = generate_invoice_output broker_invoices

            export_jobs = []

            invoice_output.each_pair do |format, output_hash|
              files << output_hash[:files] if output_hash[:files] # no file for exception format
              export_jobs << output_hash[:export_job] if output_hash[:export_job]  # export job may be nil if running in qa mode
            end
            files.flatten!

            # Email the files that were created
            delivered = false
            begin
              # Only deliver the emails if we're in prod mode (other modes can grab the file via ec2)
              if @env == :prod
                OpenMailer.send_simple_html(EMAIL_INVOICES_TO, "[chain.io] Vandegrift, Inc. RL Canada Invoices for #{start_time.strftime("%m/%d/%Y")}", email_body(broker_invoices, start_time), files).deliver!
                delivered = true
              end
            ensure
              export_jobs.each do |export_job|
                export_job.start_time = start_time
                export_job.end_time = Time.zone.now
                # Only mark prod jobs as successful, anything else shouldn't be automatically set as sent since an email isn't generated.
                # This allows us to easily generate files from the console, and grab them from s3, but not affect any automated weekly exports.
                export_job.successful = (@env == :prod && delivered)
                export_job.save
              end
            end
          ensure 
            # remove the tempfiles 
            files.each do |f|
              f.close!
            end
          end
        end
      end 

      def previously_invoiced? entry
        # We need to keep track of which entries we've seen this particular
        # run, in cases where we have multiple broker invoices to transmit and the first
        # is an MMGL one.  The second needs to be an FFI one due to the way
        # the MMGL includes all the commercial invoice duty lines - duplicating
        # those lines on the second invoice would result in issues at RL and the MMGL
        # reqires invoice lines to be included.
        found = @invoiced_entries && @invoiced_entries.include?(entry.broker_reference)

        if !found
          # Make sure we haven't previously invoiced a portion of this entry weeks ago.
          
          # The hand coded SQL is needed due to the polymorphic association
          # on the export job linker table
          completed_jobs = ExportJob.where(:successful=>true, :export_type => [ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE, ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE]).
                          joins(:export_job_links).
                          joins("INNER JOIN broker_invoices ON export_job_links.exportable_id = broker_invoices.id").
                          where(:broker_invoices => {:entry_id => entry.id}).

                          uniq
          found = completed_jobs.length > 0 
        end

        return found
      end

      def find_profit_center entry
        brand = find_rl_brand entry

        if brand
          DataCrossReference.find_rl_profit_center_by_brand brand
        else
          nil
        end
      end

      def find_rl_brand entry
        # The brand is the first 3 characters of the product for SAP PO's.
        brand_line = entry.commercial_invoice_lines.find {|line| (line.part_number.length >= 3 && sap_po?(line.po_number)) ? line : false}

        brand = nil
        if brand_line.nil?
          # If no brand is found, then this isn't an original SAP PO..
          # we should be able to find a brand using a PO -> Brand xref supplied by RL
          po_numbers = extract_po_numbers entry

          po_numbers.each do |po_number|
            brand = DataCrossReference.find_rl_brand_by_po po_number
            break unless brand.nil?
          end
        else 
          brand = brand_line.part_number[0, 3]
        end

        brand
      end

      class PoloMmglInvoiceWriter
       
       def initialize generator
          @inv_generator = generator

          @starting_row ||= 1
          @workbook ||= XlsMaker.create_workbook 'MMGL', ['Indicator_Post_invoice_or_credit_memo','Document_date_of_incoming_invoice',
            'Reference_document_number','Company_code','Different_invoicing_party','Currency_key','Gross_invoice_amount_in_document_currency','Payee',
            'Terms_of_payment_key','Baseline_date_for_due_date_calculation','Document_header_text','Lot_Number','Invoice_line_number','Purchase_order_number',
            'Material_Number','Amount_in_document_currency','Quantity','Condition_Type','Item_text','Invoice_line_number','GL_Account','Amount',
            'Debit_credit_indicator','Company_code','GL_Line_Item_Text','Profit_Center']
          @sheet ||= @workbook.worksheet(0)
        end

        # Appends the invoice information specified here to the excel file currently being generated
        # Preserve this method name for duck-typing compatibility with the other invoice output generator
        def add_invoices commercial_invoices, broker_invoice
          header_info = get_header_information broker_invoice, commercial_invoices
          XlsMaker.add_body_row @sheet, @starting_row, header_info

          commercial_invoice_info = get_commercial_invoice_information commercial_invoices
          broker_invoice_info = get_broker_invoice_information broker_invoice

          commercial_invoice_info.each_with_index do |row, i|
            XlsMaker.insert_body_row @sheet, @starting_row + i, 12, row
          end

          broker_invoice_info.each_with_index do |row, i|
            XlsMaker.insert_body_row @sheet, @starting_row + i, 19, row
          end

          # Commercial and broker invoice data is highly likely to have
          # a different number of rows for each so we need to update the row counter 
          # so the next set of invoice data is put into the row directly after the invoice data.
          @starting_row = @starting_row + [1, commercial_invoice_info.length, broker_invoice_info.length].max
          nil
        end

        def write_file
          filename = "Vandegrift_#{Time.zone.now.strftime("%Y%m%d")}_MM_Invoice"
          file = Tempfile.new([filename, ".xls"])
          file.binmode
          @workbook.write file
          
          # Blank these variables, just to prevent weirdness if the writer is attempted to be re-used...they're incapable
          # of being re-used so I want this to fail hard.
          @starting_row = nil
          @workbook = nil
          @sheet = nil
          Attachment.add_original_filename_method file
          file.original_filename = "#{filename}.xls"
          [file]
        end

        private 
          def get_header_information broker_invoice, commercial_invoices
            charge_total = get_total_invoice_sum broker_invoice, commercial_invoices
            line = []
            line << ((charge_total >= BigDecimal.new("0")) ? "X" : "")
            line << broker_invoice.invoice_date.strftime("%Y%m%d")
            line << broker_invoice.invoice_number
            line << '1017'
            line << '100023825'
            line << 'CAD'
            line << charge_total
            line << ""
            line << '0001'
            line << Time.zone.now.strftime("%Y%m%d")
            line << broker_invoice.entry.entry_number
            line << 'V'

            line
          end

          def get_total_invoice_sum broker_invoice, commercial_invoices
            total = BigDecimal.new "0.00"
            broker_invoice.broker_invoice_lines.each do |line|
              # All Duty recording is handled with commercial invoices
              total += line.charge_amount unless line.duty_charge_type?
            end

            total += broker_invoice.entry.total_duty_gst

            total
          end

          def get_commercial_invoice_information commercial_invoices
            rows = []
            counter = 0
            commercial_invoices.each do |inv|
              inv.commercial_invoice_lines.each do |line|
                row = []
                row << "#{counter += 1}"
                row << line.po_number
                row << line.part_number
                row << line.commercial_invoice_tariffs.inject(BigDecimal.new("0.00")) {|sum, t| sum + t.duty_amount}
                row << line.quantity
                row << "ZDTY"
                row << ""

                rows << row
              end
            end

            rows
          end

          def get_broker_invoice_information broker_invoice
            rows = []
            counter = 0

            # The first line here is always the GST for the Entry
            if broker_invoice.entry.total_gst > BigDecimal.new("0")
              gst_row = []
              rows << gst_row

              gst_row << "#{counter += 1}"
              gst_row << "14311000" # GL Account for GST
              gst_row << broker_invoice.entry.total_gst
              gst_row << "S"
              gst_row << '1017'
              gst_row << "GST"
              gst_row << "19999999"
            end
            
            profit_center = @inv_generator.find_profit_center(broker_invoice.entry)
            
            broker_invoice.broker_invoice_lines.each do |line|
              next if line.duty_charge_type?
              hst_line = line.hst_gst_charge_code?

              gl_account = (
                if hst_line 
                  "14311000"
                elsif line.charge_code == "22"
                  # 22 is the Brokerage charge code.  RL stated they only wanted us to send this account for the $55 brokerage
                  # fee - which is all we currently bill for under the 22 code. So rather than tie the code to a billing amount that 
                  # will probably change at some point in the future, I'm using the code.
                  "52111300"
                else
                  "52111200"
                end
              )

              row = []
              row << "#{counter += 1}"
              row << gl_account
              # All charge amounts should be positive amounts (stupid accounting systems)
              row << line.charge_amount.abs
              row << ((line.charge_amount > BigDecimal.new("0")) ? "S" : "H")
              row << "1017"
              row << line.charge_description
              row << (hst_line ? "19999999" : profit_center) # HST Lines have a different profit center than brokerage fees.

              rows << row
            end

            rows
          end
      end

      class PoloFfiInvoiceWriter

        def initialize generator
          @inv_generator = generator
        end

        # Appends the invoice information specified here to the excel file currently being generated
        # Preserve this method name for duck-typing compatibility with the other invoice output generator
        def add_invoices commercial_invoices, broker_invoice
          @document_lines ||= []

          lines = get_invoice_information broker_invoice
          if lines
            lines.each {|line| @document_lines << line}
          end
          
          nil
        end

        def write_file
          output_files = []
          return output_files unless @document_lines && @document_lines.length > 0

          filename = "Vandegrift_#{Time.zone.now.strftime("%Y%m%d")}_FFI_Invoice"
          xls_file = Tempfile.new([filename, ".xls"])
          xls_file.binmode

          workbook = XlsMaker.create_workbook 'FFI', [
              "Document Date", "Document Type", "Company Code", "Posting Date", "Currency", "Exchange Rate", "Translation Date",
              "Document Header Text", "Reference", "Posting Key", "G/L A/c/ Vendor/ Customer", "New Co Code", "Amount",
              "Payment Terms", "Baseline Date", "Payment Method", "Payment Method Supplement", "Payment Block", "Trading Partner",
              "Tax Code", "Tax Amount", "Value Date", "Cost Center", "WBS Element", "Profit Center", "Business Area",
              "Assignment", "Line Item Text", "Reversal Reason", "Reversal Date", "Tax Jurisdiction Code"]
          sheet = workbook.worksheet(0)
          starting_row = 1

          @document_lines.each_with_index do |row, i|
            XlsMaker.add_body_row sheet, starting_row + i, row
          end

          workbook.write xls_file
          Attachment.add_original_filename_method xls_file
          xls_file.original_filename = "#{filename}.xls"
          output_files << xls_file

          # Now create a tab delimited text file of the same data (sans headers)
          # The tab delimited file is fed into RL's computer system, which apparently can't accept the xls one.
          # The xls one is for human consumption
          tab_file = Tempfile.new([filename, ".txt"])
          CSV.open(tab_file, "wb", {:col_sep=>"\t", :row_sep=>"\r\n"}) do |csv|
            @document_lines.each do |row|
              csv << row
            end
            csv.flush
          end
          Attachment.add_original_filename_method tab_file
          tab_file.original_filename = "#{filename}.txt"
          output_files << tab_file

          @document_lines = nil
          output_files
        end

        private 

          def get_invoice_information broker_invoice
            rows = []

            raw_profit_center = @inv_generator.find_profit_center(broker_invoice.entry)

            # If no profit center is found..we fall back to using the "catch all" one for non-deployed brands
            profit_center = raw_profit_center.blank? ? "19999999" : raw_profit_center

            # We only need to output the Duty and GST lines if this entry hasn't already been invoiced.
            unless @inv_generator.previously_invoiced? broker_invoice.entry
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, "23101230", profit_center, broker_invoice.entry.total_duty, "Duty", :duty, broker_invoice.entry.entry_number)
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, "14311000", profit_center, broker_invoice.entry.total_gst, "GST", :gst, broker_invoice.entry.entry_number)
            end

            # Deployed brands (ie. we have a profit center for the entry/po) use a different G/L account than non-deployed brands
            brokerage_gl_account = raw_profit_center.blank? ? "23101900" : "52111200"

            broker_invoice.broker_invoice_lines.each do |line|
              # Duty is included at the "header" level so skip it at the invoice line level
              next if line.duty_charge_type?
              gl_account = line.hst_gst_charge_code? ? "14311000" : brokerage_gl_account
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, gl_account, profit_center, line.charge_amount, line.charge_description, :brokerage, broker_invoice.entry.entry_number)
            end

            # There always needs to be a "total" line, regardless of whether there's duty / gst listed or not,
            # It needs to be the sum of all the brokerage charge and duty/gst lines
            total_amount = rows.inject(BigDecimal.new("0.00")) {|sum, row| sum + row[12]}

            rows.insert(0, create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, "100023825", "49999999", total_amount, "", :total, broker_invoice.entry.entry_number))

            # For any invoices where the total invoice amount is a credit (ie. total_amount < 0) we need to assign different document types and posting keys
            # and ensure all amounts are positive values
            if total_amount <= 0
              rows.each do |row|
                row[1] = "KG"
                row[9] = ((row[9] == "31") ? "21" : "50")
                row[12] = row[12].abs
              end
            end

            rows
          end

          def create_line invoice_number, invoice_date, gl_account, profit_center, amount, description, line_type, entry_number
            now = Time.zone.now.strftime("%m/%d/%Y")

            row = []
            row << invoice_date.strftime("%m/%d/%Y")
            row << "KR"
            row << "1017"
            row << now
            row << "CAD"
            row << nil
            row << nil
            row << nil
            row << invoice_number
            row << (line_type == :total ? "31" : "40")
            row << gl_account
            row << nil
            row << amount
            row << '0001'
            row << now
            row << nil
            row << nil
            row << nil
            row << nil
            row << nil
            row << nil
            row << nil
            row << nil
            row << nil
            row << profit_center
            row << nil
            row << entry_number
            row << (description.blank?  ? nil : description[0,50]) #Only allows 50 chars max (blank/nil is just to make output between xls and txt easier to test)

            row
          end
      end

      class PoloExceptionInvoiceWriter

        def add_invoice broker_invoice, error
          @broker_invoice_data ||= []
          @broker_invoice_data << {:number=> broker_invoice.invoice_number, :error => error}
        end

        def write_file
          # We may at some point want to include some reason why the invoice couldn't
          # be processed, but at this point, we'll just make a spreadsheet with a list of
          # invoice numbers that we couldn't handle.
          return if @broker_invoice_data.nil? || @broker_invoice_data.length == 0

          workbook ||= XlsMaker.create_workbook 'Exceptions', ["Invoice Number", "Error", "Backtrace"]
          sheet ||= workbook.worksheet(0)
          starting_row = 0
          @broker_invoice_data.each do |data| 

            XlsMaker.add_body_row sheet, (starting_row += 1), [data[:number], data[:error].message, data[:error].backtrace.join("\n")]
          end
          
          file = Tempfile.new(["RL_Canada_Invoice_Exceptions_#{Time.zone.now.strftime("%Y%m%d")}_", ".xls"])
          file.binmode
          workbook.write file

          # The easiest way for us to send an email to the appropriate people to handle
          # this issue now is just to raise and log an exception
          begin
            raise "Failed to generate #{broker_invoice_data.length} RL Canada invoices."
          rescue 
            $!.log_me ["See attached spreadsheet for full list of invoice numbers that could not be generated."], [file.path]
          end
          @broker_invoice_data = nil
          nil
        end
      end

      private 
        def email_body broker_invoices, start_time
          # This can include HTML if we want.
          "An MM and/or FFI invoice file is attached for RL Canada for #{broker_invoices.length} invoices as of #{start_time.strftime("%m/%d/%Y")}."
        end

        def generate_invoice_output broker_invoices
          # This set is used so that we don't attempt to generate multiple mmgl invoices
          # against the same entry.  It's basically here because we're not saving the export
          # jobs until after files are actually written and attached to the export jobs.
          @invoiced_entries ||= Set.new
          writers = {}
          export_jobs = {}

          broker_invoices.each do |broker_invoice|
            begin
              format = determine_invoice_output_format(broker_invoice)
              writer = create_writer(format)

              if writer
                writers[format] ||= writer
                writer.add_invoices broker_invoice.entry.commercial_invoices, broker_invoice

                if log_job? format
                  # Make sure we record this broker invoice against the export job it belongs to
                  export_jobs[format] ||= build_export_job format
                  export_jobs[format].export_job_links.build.exportable = broker_invoice
                end

                @invoiced_entries << broker_invoice.entry.broker_reference
              end
            rescue
              # Catch any errors and write them out using another writer format
              writer = create_writer(:exception)
              writers[:exception] ||= writer
              writer.add_invoice broker_invoice, $!
            end
           
          end

          invoice_output = {}

          writers.each_pair do |format, writer|
            output_files = writer.write_file
            export_job = export_jobs[format]

            # Some outputs purposefully may not result in export jobs or files (.ie the exception report)
            if export_job && output_files
              output_files.each do |file|
                attachment = export_job.attachments.build
                attachment.attached = file
              end
            
              export_job.save!
            end

            # We technically could destroy the tempfile here and then
            # look up the output data again via the export job attachments,
            # but it's much more efficient (though slightly clumsier) to 
            # pass the file back and send it directly
            invoice_output[format] = {:export_job => export_job, :files=>output_files}
          end

          @output_writers = nil
         
          invoice_output
        end

        def log_job? format
          return format != :exception
        end

        def determine_invoice_output_format broker_invoice
          output_format = nil

          # Can we find an actual Brand?
          # This applies to both SAP and non-SAP PO's
          brand = find_rl_brand(broker_invoice.entry)

          if brand
            # If we can find a profit center, then we can possibly use the MM interface
            profit_center = find_profit_center broker_invoice.entry

            if profit_center
              # We can't handle multiple MM invoices for the same entry because we 
              # send all the po/commercial invoice information for an entry on the first transmission
              # of the first broker invoice.  The MM interface requires PO information for all invoices
              # and we can't resend the full invoice line set again (otherwise the duty will get added twice in RL's system).
              # So we fall back to sending via the FFI interface.
              if !previously_invoiced?(broker_invoice.entry)
                output_format = :mmgl
              end
            end
          end

          output_format = :ffi unless output_format
          output_format
        end

        def create_writer output_format
          @output_writers ||= {}
          output = nil

          if output_format == :mmgl
            @output_writers[output_format] ||= PoloMmglInvoiceWriter.new(self)
            output = @output_writers[output_format]
          elsif output_format == :ffi
            @output_writers[output_format] ||= PoloFfiInvoiceWriter.new(self)
            output = @output_writers[output_format]
          elsif output_format == :exception
            @output_writers[output_format] ||= PoloExceptionInvoiceWriter.new
            output = @output_writers[output_format]
          end

          output
        end

        def has_sap_po? entry
          # SAP PO's all start with '47'
          return !entry.po_numbers.blank? && extract_po_numbers(entry).find {|po| sap_po? po}
        end

        def extract_po_numbers entry
          entry.po_numbers.nil? ? [] : entry.po_numbers.split(/\s*\n\s*/)
        end

        def sap_po? po_number
          po_number =~ /^\s*47/
        end

        def build_export_job format
          job = ExportJob.new
          job.start_time = Time.zone.now
          job.export_type = ((format == :mmgl) ? ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE : ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)

          job
        end
    end
  end
end
