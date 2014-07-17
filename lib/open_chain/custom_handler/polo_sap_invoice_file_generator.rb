require 'bigdecimal'
require 'tempfile'
require 'csv'
require 'open_chain/xml_builder'
require 'open_chain/custom_handler/polo/polo_business_logic'
require 'open_chain/api/product_api_client'

module OpenChain
  module CustomHandler
    class PoloSapInvoiceFileGenerator
      include Polo::PoloBusinessLogic
      include OpenChain::FtpFileSupport

      # These are the ONLY the RL Canada importer accounts we're doing automatically, other RL accounts are done by hand for now
      RL_INVOICE_CONFIGS ||= {
        :rl_canada => {name: "RL Canada", tax_id: '806167003RM0001', start_date: Date.new(2013, 6, 01), 
          email_to: ["joanne.pauta@ralphlauren.com", "james.moultray@ralphlauren.com", "dean.mark@ralphlauren.com", "accounting-ca@vandegriftinc.com"],
          unallocated_profit_center: "19999999", company_code: "1017", filename_prefix: "RL"
        }, 
        :club_monaco => {name: "Club Monaco", tax_id: '866806458RM0001', start_date: Date.new(2014, 5, 23), email_to: ["joanne.pauta@ralphlauren.com", "matthew.dennis@ralphlauren.com", "jude.belas@ralphlauren.com", "robert.helm@ralphlauren.com", "accounting-ca@vandegriftinc.com"],
          unallocated_profit_center: "20399999", company_code: "1710", filename_prefix: "CM"
        }
      }

      def initialize env = :prod, custom_where = nil
        # you can use a non-:prod env to prevent the documents from being emailed / ftp'ed and then use the export job attachments created
        # to pull the files if you need to examine them.  This also prevents the export jobs from being marked as completed, thus meaning
        # the next prod run the data from the files will be included in generated data.
        @env = env
        @custom_where = custom_where
      end

      def api_client
        @api_client ||= OpenChain::Api::ProductApiClient.new 'polo'
      end

      def self.run_schedulable opts = {}
        PoloSapInvoiceFileGenerator.new.find_generate_and_send_invoices
      end

      def find_generate_and_send_invoices 
        Time.use_zone("Eastern Time (US & Canada)") do
          RL_INVOICE_CONFIGS.each_pair do |rl_company, conf|
            start_time = Time.zone.now
            invoices = find_broker_invoices rl_company
            generate_and_send_invoices rl_company, start_time, invoices
          end
        end
      end

      def find_broker_invoices rl_company
        # We should be fine eager loading everything here since we're doing these week by week.
        # It shouldn't be THAT much data, at least at this point.
        conf = RL_INVOICE_CONFIGS[rl_company]
        query = BrokerInvoice.select("distinct broker_invoices.*").
                joins(:entry).
                # This needs to be part of the standard query clause, even if there's custom where clauses
                # otherwise we're going to end up with results for every pass over the configs, which we don't
                # want.
                where(:entries => {:importer_tax_id => conf[:tax_id]}).
                order("broker_invoices.invoice_date ASC")


        if @custom_where
          # Presumably, for the QA case, we're just going to be listing specific invoice #'s
          # Or at least something that limits the invoice output
          query = query.where(@custom_where)
        else
          query = query.
                    where("broker_invoices.invoice_date >= ?", conf[:start_date]).
                    # We need to exclude everything that has already been successfully invoiced
                    joins("LEFT OUTER JOIN export_job_links ejl ON broker_invoices.id = ejl.exportable_id AND ejl.exportable_type = 'BrokerInvoice'").
                    joins("LEFT OUTER JOIN export_jobs ej on ejl.export_job_id = ej.id and ej.successful = true and ej.export_type in ('#{ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE}', '#{ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE}')").
                    where("ej.id IS NULL").
                    # We need to also exclude everything that is in a Fail or Review Business Rule state
                    joins("LEFT OUTER JOIN business_validation_results bvr ON bvr.validatable_id = entries.id AND bvr.validatable_type = 'Entry' AND bvr.state IN ('Fail')").
                    where("bvr.id IS NULL")
        end

        query.all
      end

      def generate_and_send_invoices rl_company, start_time, broker_invoices
       # Send them 
        if broker_invoices.length > 0
          files = {}
          begin
            invoice_output = generate_invoice_output rl_company, broker_invoices

            export_jobs = []

            invoice_output.each_pair do |format, output_hash|
              output_hash[:files].each_pair do |send_format, send_files|
                files[send_format] ||= []
                files[send_format] += send_files
              end
              # might be a missing export job if the format encountered an exception
              export_jobs << output_hash[:export_job] if output_hash[:export_job]
            end

            # Email the files that were created
            delivered = false
            begin
              # Only ftp or deliver emails if we're in prod mode (other modes can grab the file via ec2)
              if @env == :prod
                unless files[:ftp].blank?
                  files[:ftp].each {|f| ftp_file f}
                end
                # If the FTP worked, I'm considering them delivered.  The email is purely for informational purposes now.
                delivered = true

                unless files[:email].blank?
                  conf = RL_INVOICE_CONFIGS[rl_company]
                  OpenMailer.send_simple_html(conf[:email_to], "[VFI Track] Vandegrift, Inc. #{conf[:name]} Invoices for #{start_time.strftime("%m/%d/%Y")}", email_body(conf[:name], broker_invoices, start_time), files[:email]).deliver!
                end
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
            files.values.flatten.each do |f|
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
          DataCrossReference.find_rl_profit_center_by_brand entry.importer_id, brand
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

      def ftp_credentials
        ftp2_vandegrift_inc 'to_ecs/Ralph_Lauren/sap_invoices'
      end

      def set_product? part_number
        @set_product_cache ||= {}

        is_set = @set_product_cache[part_number]
        return is_set unless is_set.nil?
      
        response = api_client.find_by_uid part_number, ['class_cntry_iso', '*cf_131']
        if response && response['product']
          is_set = false

          product = response['product']
          if product && product['classifications']
            set_type = product['classifications'].find {|c| c['class_cntry_iso'] == 'CA'}.try(:[], "*cf_131")
            is_set = !set_type.blank?
          end

          @set_product_cache[part_number] = is_set
        end
        
        is_set
      rescue => e
        # Don't bother logging the 404 not found error raised by the client since we'll end up reporting on it anyway, we do want to log any other error though.
        if !e.is_a?(OpenChain::Api::ApiClient::ApiError) || e.http_status.to_s != "404"
          e.log_me "Failed to retrieve product information for style #{part_number} from RL VFI Track instance."
        end
        nil
      end

      class PoloMmglInvoiceWriter
        include OpenChain::XmlBuilder
       
       def initialize generator, config
          @inv_generator = generator
          @config = config

          @starting_row = 1
          @workbook = XlsMaker.create_workbook 'MMGL', ['Indicator_Post_invoice_or_credit_memo','Document_date_of_incoming_invoice',
            'Reference_document_number','Company_code','Different_invoicing_party','Currency_key','Gross_invoice_amount_in_document_currency','Payee',
            'Terms_of_payment_key','Baseline_date_for_due_date_calculation','Document_header_text','Lot_Number','Invoice_line_number','Purchase_order_number',
            'Material_Number','Amount_in_document_currency','Quantity','Condition_Type','Item_text','Invoice_line_number','GL_Account','Amount',
            'Debit_credit_indicator','Company_code','GL_Line_Item_Text','Profit_Center']
          @sheet = @workbook.worksheet(0)

          @document, @root = build_xml_document "Invoices"
          @errors = []
        end

        # Appends the invoice information specified here to the excel/xml files currently being generated
        # Preserve this method name for duck-typing compatibility with the other invoice output generator
        def add_invoices commercial_invoices, broker_invoice
          header_info = get_header_information broker_invoice, commercial_invoices
          XlsMaker.add_body_row @sheet, @starting_row, header_info

          inv_el = add_element @root, "Invoice"
          write_header_xml inv_el, header_info

          commercial_invoice_info = get_commercial_invoice_information commercial_invoices
          broker_invoice_info = get_broker_invoice_information broker_invoice

          items_el = add_element inv_el, "Items"
          commercial_invoice_info.each_with_index do |row, i|
            # We needed to tack on some extra information for the commercial invoices ()
            XlsMaker.insert_body_row @sheet, @starting_row + i, 12, row
            write_commercial_invoice_line_xml items_el, row, header_info[5]
          end

          gl_el = add_element inv_el, "GLAccounts"
          broker_invoice_info.each_with_index do |row, i|
            XlsMaker.insert_body_row @sheet, @starting_row + i, 19, row
            write_broker_invoice_line_xml gl_el, row
          end

          # Commercial and broker invoice data is highly likely to have
          # a different number of rows for each so we need to update the row counter 
          # so the next set of invoice data is put into the row directly after the invoice data.
          @starting_row = @starting_row + [1, commercial_invoice_info.length, broker_invoice_info.length].max
          nil
        end

        def write_header_xml parent_el, h
          header_el = add_element parent_el, "HeaderData"
          add_element header_el, "Indicator", h[0]
          add_element header_el, "DocumentType", "RE"
          add_element header_el, "DocumentDate", h[1]
          add_element header_el, "PostingDate", h[9]
          add_element header_el, "Reference", h[2]
          add_element header_el, "CompanyCode", h[3]
          add_element header_el, "DifferentInvoicingParty", h[4]
          add_element header_el, "CurrencyCode", h[5]
          add_element header_el, "Amount", h[6]
          add_element header_el, "PaymentTerms", h[8]
          add_element header_el, "BaseLineDate", h[9]
          nil
        end

        def write_commercial_invoice_line_xml parent_el, l, currency
          item_el = add_element parent_el, "ItemData"
          add_element item_el, "InvoiceDocumentNumber", l[0]
          add_element item_el, "PurchaseOrderNumber", l[1]
          add_element item_el, "PurchasingDocumentItemNumber", l[2]
          add_element item_el, "AmountDocumentCurrency", l[3]
          add_element item_el, "Currency", currency
          add_element item_el, "Quantity", l[4]
          add_element item_el, "ConditionType", l[5]
          nil
        end

        def write_broker_invoice_line_xml parent_el, l
          gl_el = add_element parent_el, "GLAccountData"

          add_element gl_el, "DocumentItemInInvoiceDocument", l[0]
          add_element gl_el, "GLVendorCustomer", l[1]
          add_element gl_el, "Amount", l[2]
          add_element gl_el, "DocumentType", l[3]
          add_element gl_el, "CompanyCode", l[4]
          add_element gl_el, "LineItemText", l[5]
          add_element gl_el, "ProfitCenter", l[6]
          nil
        end

        def write_file
          output_files = {}

          filename = "Vandegrift MM #{@config[:filename_prefix]} #{Time.zone.now.strftime("%Y%m%d")}"
          file = Tempfile.new([filename, ".xls"])
          file.binmode
          @workbook.write file
          Attachment.add_original_filename_method file
          file.original_filename = "#{filename}.xls"
          emails = [file]

          # Generate an exception log email from the collected errors regarding missing Tradecard invoice or Chain product records
          unless @errors.blank?
            workbook = XlsMaker.create_workbook 'MMGL Exceptions', ["Entry #", "Commercial Invoice #", "PO #", "SAP Line #", "Error"]
            sheet = workbook.worksheet(0)
            row_num = 0
            @errors.each do |row|
              XlsMaker.add_body_row sheet, (row_num += 1), row
            end

            exception_file = "#{filename} Exceptions"
            file = Tempfile.new([exception_file, ".xls"])
            file.binmode
            workbook.write file
            Attachment.add_original_filename_method file
            file.original_filename = "#{exception_file}.xls"
            emails << file
          end

          output_files[:email] = emails

          xml_file = Tempfile.new([filename, ".xml"])
          xml_file.binmode
          @document.write xml_file
          xml_file.flush
          Attachment.add_original_filename_method xml_file
          xml_file.original_filename = "#{filename}.xml"
          output_files[:ftp] = [xml_file]
          
          # Blank these variables, just to prevent weirdness if the writer is attempted to be re-used...they're incapable
          # of being re-used so I want this to fail hard.
          @starting_row = nil
          @workbook = nil
          @sheet = nil
          @document = nil
          @root = nil
          @errors = nil
         
          output_files
        end

        private 
          def get_header_information broker_invoice, commercial_invoices
            charge_total = get_total_invoice_sum broker_invoice, commercial_invoices
            line = []
            line << ((charge_total >= BigDecimal.new("0")) ? "X" : "")
            line << broker_invoice.invoice_date.strftime("%Y%m%d")
            line << broker_invoice.invoice_number
            line << @config[:company_code]
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
            
            # For each line, we need to find the corresponding Tradecard 810 line 
            # and use the quantity value (IT102) found on there for all lines (except non-prepack / non-set lines).

            # For any Tradecard 810 lines that have IT103 == "AS" (unit of measure) we'll need to combine
            # all lines together that have the same SAP PO / Line numbers, sum'ing the 
            # duty amounts for the single line sent.  These are prepacks that have been split 
            # onto multiple invoice lines and need to be recombined.

            # For Tradecard 810 lines that have IT103 != "AS". Look up the product
            # by part number and find out if it's a set by looking at the CA classification
            # for a non-blank Set Type custom field.

            # If it is not a set, then sum the quantity values from the commercial invoice lines
            # If it is a set, use the Tradecard 810 IT102 quantity value and sum the duty amount
            invoice_line_info = {}
            commercial_invoices.each do |inv|
              tradecard_invoice = find_tradecard_invoice inv.invoice_number

              inv.commercial_invoice_lines.each do |line|
                # First things first, lets make sure we have a po_number and an SAP line number
                # either directly from the invoice part number or by looking up the data from the PO
                po_number, sap_line_number = find_po_sap_line_number @config[:tax_id], line

                tradecard_line = find_tradecard_line(tradecard_invoice, po_number, sap_line_number) if tradecard_invoice

                set_product = nil
                po_number = nil
                sap_line_number = nil
                prepack = nil

                # Rollup any lines that are sets or are prepacks by their po / part number
                # Prepacks are supposed to all be on Tradecard lines...it's possible we could also 
                # find if the style is a prepack by looking to the Order as well.
                if tradecard_line && @inv_generator.prepack_indicator?(tradecard_line.unit_of_measure)
                  po_number, sap_line_number = @inv_generator.split_sap_po_line_number line.po_number
                  prepack = true
                  set_product = false
                else
                  # Only look up the product if a Tradecard invoice exists...there's no point 
                  # to looking it up if it doesn't exist since there's no quantity to pull from
                  # and the call is rather expensive to make (since it's an http request to another system)
                  if tradecard_invoice
                    set_product = @inv_generator.set_product? line.part_number                    
                  else
                    set_product = false
                  end

                  # Find the SAP Line number for the style (which may be a part of the invoice PO #)
                  # If it's not, we have to go back to the PO and see which line matches our part
                  po_number, sap_line_number = @inv_generator.split_sap_po_line_number line.po_number
                  if sap_line_number.blank?
                    sap_line_number = get_sap_line_from_order(@config[:tax_id], po_number, line.part_number)
                  end
                end

                invoice_line_group = "#{po_number}~#{sap_line_number}"

                invoice_line_info[invoice_line_group] ||= {inv_lines: []}
                invoice_line_info[invoice_line_group][:inv_lines] << line
                invoice_line_info[invoice_line_group][:tradecard_line] ||= tradecard_line
                invoice_line_info[invoice_line_group][:po_number] ||= po_number
                invoice_line_info[invoice_line_group][:sap_line_number] ||= sap_line_number
                invoice_line_info[invoice_line_group][:set_product] ||= set_product
                invoice_line_info[invoice_line_group][:prepack] ||= prepack
              end
            end

            rows = []
            counter = 0
            invoice_line_info.each do |po_line_number, values|
              # We need to look up the product here from the RL VFITrack instance to determine if it's a set or not
              # If we can't find the product, we'll continue like it's not a set but we need to generate some sort
              # of error reference indicating that the product couldn't be found.
              line = values[:inv_lines].first

              # There's two things we need to error on..
                # 1) Missing product definition (don't need this if product is a prepack)
                # 2) Missing Tradecard Invoice if Set or Prepack

              # nil indicates a lookup failure, if the lookup worked then we expect a true/false value instead
              if !values[:prepack] && values[:set_product].nil?
                @errors << create_errors_line(values, :missing_product)
              elsif (values[:set_product] || values[:prepack]) && values[:tradecard_line].nil? 
                # We need the tradecard invoice for sets, otherwise we may not have the correct quantity
                @errors << create_errors_line(values, :missing_810)
              end

              if (values[:set_product] || values[:prepack]) && values[:tradecard_line]
                # Since this is a set and we have a tradecard line, we need to use the tradecard invoice's quantity value
                rows << create_mmgl_line((counter += 1), values[:tradecard_line].quantity, values[:po_number], values[:sap_line_number], values[:inv_lines])
              else
                # Since this isn't a set (or product / tradecard information is missing), the product is the sum of the entered quantity for the invoice lines
                quantity = values[:inv_lines].inject(BigDecimal.new("0.00")) {|sum, line| sum + line.quantity}
                rows << create_mmgl_line((counter += 1), quantity, values[:po_number], values[:sap_line_number], values[:inv_lines])
              end
            end

            rows
          end

          def find_tradecard_invoice invoice_number
            CommercialInvoice.where(invoice_number: invoice_number, vendor_name: "Tradecard").includes(:commercial_invoice_lines).first
          end

          def find_po_sap_line_number importer_tax_id, invoice_line
            inv_po, inv_po_line_number = @inv_generator.split_sap_po_line_number invoice_line.po_number

            if inv_po_line_number.blank?
              inv_po_line_number = get_sap_line_from_order importer_tax_id, invoice_line.po_number, invoice_line.part_number
            end
            
            [inv_po, inv_po_line_number]
          end

          def find_tradecard_line tradecard_invoice, inv_po, inv_po_line_number
            tradecard_invoice.commercial_invoice_lines.find do |line|
              po_number, line_number = @inv_generator.split_sap_po_line_number line.po_number

              inv_po == po_number && inv_po_line_number == line_number
            end
          end

          def create_errors_line values, error_type
            row = []
            row[0] = values[:inv_lines][0].entry.entry_number
            row[1] = values[:inv_lines][0].commercial_invoice.invoice_number
            row[2] = values[:po_number]
            row[3] = values[:sap_line_number]
            row[4] = (error_type == :missing_810) ? "No Tradecard Invoice line found for PO # #{values[:po_number]} / SAP Line #{values[:sap_line_number]}" : "No VFI Track product found for style #{values[:inv_lines][0].part_number}."

            row
          end

          def create_mmgl_line counter, quantity, po_number, sap_line_number, invoice_lines
            total_duty = invoice_lines.collect{|l| l.commercial_invoice_tariffs}.flatten.inject(BigDecimal.new("0.00")) {|sum, t| sum + t.duty_amount}

            line = invoice_lines.first

            row = []
            row << "#{counter}"
            row << po_number
            row << sap_line_number
            row << total_duty
            row << quantity
            row << "ZDTY"
            row << ""

            row
          end

          def get_sap_line_from_order importer_tax_id, po_number, style
            # We're just pulling the first PO line that has the same Style.  If this ends up being an issue we may have to 
            # add additional heuristics from the PO into the mix.
            order_line = OrderLine.
                          joins(:order, :product).
                          where(orders: {order_number: "#{importer_tax_id}-#{po_number}"}, products: {unique_identifier: "#{importer_tax_id}-#{style}"}).
                          order("order_lines.line_number ASC").first
            line_number = order_line.try(:line_number)
            if line_number
              # The line number isn't going to be formatted correctly at this point (since it's stored as an int in the DB)
              # Just use the sap po split function to reformat it to the desired string
              po, line = @inv_generator.split_sap_po_line_number "#{po_number}-#{line_number.to_s}"
              line
            else
              nil
            end
            
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
              gst_row << @config[:company_code]
              gst_row << "GST"
              gst_row << @config[:unallocated_profit_center]
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
              row << @config[:company_code]
              row << line.charge_description
              row << (hst_line ? @config[:unallocated_profit_center] : profit_center) # HST Lines have a different profit center than brokerage fees.

              rows << row
            end

            rows
          end
      end

      class PoloFfiInvoiceWriter
        include OpenChain::XmlBuilder

        def initialize generator, rl_company, config
          @inv_generator = generator
          @rl_company = rl_company
          @config = config
          @document_lines ||= []
          @document, root = build_xml_document "Invoices"
        end

        # Appends the invoice information specified here to the excel file currently being generated
        # Preserve this method name for duck-typing compatibility with the other invoice output generator
        def add_invoices commercial_invoices, broker_invoice
          lines = get_invoice_information broker_invoice

          unless lines.blank?
            lines.each {|line| @document_lines << line}
            inv_el = add_element @document.root, "Invoice"
            header_el = add_element inv_el, "HeaderData"
            # The header data is always the first line
            header = lines.first
            add_element header_el, "COMPANYCODE", header[2]
            add_element header_el, "DOCUMENTTYPE", header[1]
            add_element header_el, "DOCUMENTDATE", (header[0] ? header[0].strftime("%Y%m%d") : "")
            add_element header_el, "POSTINGDATE", (header[3] ? header[3].strftime("%Y%m%d") : "")
            add_element header_el, "REFERENCE", header[8]
            add_element header_el, "INVOICINGPARTY", header[10]
            add_element header_el, "AMOUNT", header[12]
            add_element header_el, "CURRENCYCODE", header[4]
            add_element header_el, "BASELINEDATE", (header[3] ? header[3].strftime("%Y%m%d") : "")

            accounts_el = add_element inv_el, "GLAccountDatas"
            lines[1..-1].each do |line|
              gl_el = add_element accounts_el, "GLAccountData"
              add_element gl_el, "COMPANYCODE", line[2]
              add_element gl_el, "GLVENDORCUSTOMER", line[10]
              # KR = Debit charge type (.ie we're charging them)
              add_element gl_el, "CreditDebitIndicator", (line[1] == "KR" ? "S" : "H")
              add_element gl_el, "AMOUNT", line[12]
              add_element gl_el, "PROFITCENTER", line[24]
            end
          end
          
          nil
        end

        def write_file
          output_files = {}
          return output_files unless @document_lines && @document_lines.length > 0

          filename = "Vandegrift FI #{@config[:filename_prefix]} #{Time.zone.now.strftime("%Y%m%d")}"
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
            # Format the dates as m/d/Y
            dup_row = row.dup
            dup_row[0] = (row[0] ? row[0].strftime("%m/%d/%Y") : "")
            dup_row[3] = (row[3] ? row[3].strftime("%m/%d/%Y") : "")
            dup_row[6] = (row[6] ? row[6].strftime("%m/%d/%Y") : "")
            dup_row[14] = (row[14] ? row[14].strftime("%m/%d/%Y") : "")

            XlsMaker.add_body_row sheet, starting_row + i, dup_row
          end

          workbook.write xls_file
          Attachment.add_original_filename_method xls_file
          xls_file.original_filename = "#{filename}.xls"
          output_files[:email] = [xls_file]

          xml_file = Tempfile.new([filename, ".xml"])
          xml_file.binmode
          @document.write xml_file
          xml_file.flush
          Attachment.add_original_filename_method xml_file
          xml_file.original_filename = "#{filename}.xml"
          output_files[:ftp] = [xml_file]

          @document = nil
          @root = nil
          @document_lines = nil
          output_files
        end

        private 

          def get_invoice_information broker_invoice
            rows = []

            raw_profit_center = @inv_generator.find_profit_center(broker_invoice.entry)

            # If no profit center is found..we fall back to using the "catch all" one for non-deployed brands
            profit_center = raw_profit_center.blank? ? @config[:unallocated_profit_center] : raw_profit_center

            # We only need to output the Duty and GST lines if this entry hasn't already been invoiced.
            unless @inv_generator.previously_invoiced? broker_invoice.entry
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, "23101230", profit_center, broker_invoice.entry.total_duty, "Duty", :duty, broker_invoice.entry.entry_number)
              # RL Canada probably should be using the unallocated account here too, but we haven't been doing that from the start so we're keeping this as is for the momemnt
              # Joanne from RL will let us know if we can use it instead of raw one
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, "14311000", hst_gst_profit_center(profit_center), broker_invoice.entry.total_gst, "GST", :gst, broker_invoice.entry.entry_number)
            end

            # Deployed brands (ie. we have a profit center for the entry/po) use a different G/L account than non-deployed brands
            brokerage_gl_account = raw_profit_center.blank? ? "23101900" : "52111200"

            broker_invoice.broker_invoice_lines.each do |line|
              # Duty is included at the "header" level so skip it at the invoice line level
              next if line.duty_charge_type?
              gl_account = line.hst_gst_charge_code? ? "14311000" : brokerage_gl_account
              local_profit_center = (line.hst_gst_charge_code? ? (hst_gst_profit_center(profit_center)) : profit_center)
              rows << create_line(broker_invoice.invoice_number, broker_invoice.invoice_date, gl_account, local_profit_center, line.charge_amount, line.charge_description, :brokerage, broker_invoice.entry.entry_number)
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

          def hst_gst_profit_center main_profit_center
            @rl_company == :rl_canada ? main_profit_center : @config[:unallocated_profit_center]
          end

          def create_line invoice_number, invoice_date, gl_account, profit_center, amount, description, line_type, entry_number
            now = Time.zone.now

            row = []
            row << invoice_date
            row << "KR"
            row << @config[:company_code]
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

        def initialize config
          @config = config
        end

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
          
          file = Tempfile.new(["#{@config[:name].gsub(" ", "_")}_Invoice_Exceptions_#{Time.zone.now.strftime("%Y%m%d")}_", ".xls"])
          file.binmode
          workbook.write file

          # The easiest way for us to send an email to the appropriate people to handle
          # this issue now is just to raise and log an exception
          begin
            raise "Failed to generate #{broker_invoice_data.length} #{@config[:name]} invoices."
          rescue 
            $!.log_me ["See attached spreadsheet for full list of invoice numbers that could not be generated."], [file.path]
          end
          @broker_invoice_data = nil
          nil
        end
      end

      private 
        def email_body rl_company_name, broker_invoices, start_time
          # This can include HTML if we want.
          "An MM and/or FFI invoice file is attached for #{rl_company_name} for #{broker_invoices.length} #{"invoice".pluralize(broker_invoices.length)} as of #{start_time.strftime("%m/%d/%Y")}."
        end

        def generate_invoice_output rl_company, broker_invoices
          # This set is used so that we don't attempt to generate multiple mmgl invoices
          # against the same entry.  It's basically here because we're not saving the export
          # jobs until after files are actually written and attached to the export jobs.
          @invoiced_entries ||= Set.new
          writers = {}
          export_jobs = {}

          broker_invoices.each do |broker_invoice|
            # Refind the invoice, preloading the invoice lines, entry and com inv lines
            broker_invoice = BrokerInvoice.where(id: broker_invoice.id).includes([{:entry=>{:commercial_invoices=>:commercial_invoice_lines}}, :broker_invoice_lines]).first
            # This should never happen, but don't blow up if it does
            next unless broker_invoice
            begin
              format = determine_invoice_output_format(broker_invoice)
              writer = create_writer(rl_company, format)

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
            rescue => e
              # Catch any errors and write them out using another writer format
              writer = create_writer(rl_company, :exception)
              writers[:exception] ||= writer
              writer.add_invoice broker_invoice, e

            end
           
          end

          invoice_output = {}
          writers.each_pair do |format, writer|
            output_files = writer.write_file
            export_job = export_jobs[format]

            # Some outputs purposefully may not result in export jobs or files (.ie the exception report)
            if export_job && output_files
              output_files.each do |type, files|
                files.each do |file|
                  attachment = export_job.attachments.build
                  attachment.attached = file
                end
              end
            
              export_job.save!
            end

            # We technically could destroy the tempfile here and then
            # look up the output data again via the export job attachments,
            # but it's much more efficient (though slightly clumsier) to 
            # pass the file back and send it directly
            invoice_output[format] = {:export_job => export_job, :files=>output_files} if log_job?(format)
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

        def create_writer rl_company, output_format
          @output_writers ||= {}
          output = nil

          config = RL_INVOICE_CONFIGS[rl_company]
          if output_format == :mmgl
            @output_writers[output_format] ||= PoloMmglInvoiceWriter.new(self, config)
            output = @output_writers[output_format]
          elsif output_format == :ffi
            @output_writers[output_format] ||= PoloFfiInvoiceWriter.new(self, rl_company, config)
            output = @output_writers[output_format]
          elsif output_format == :exception
            @output_writers[output_format] ||= PoloExceptionInvoiceWriter.new(config)
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

        def build_export_job format
          job = ExportJob.new
          job.start_time = Time.zone.now
          job.export_type = ((format == :mmgl) ? ExportJob::EXPORT_TYPE_RL_CA_MM_INVOICE : ExportJob::EXPORT_TYPE_RL_CA_FFI_INVOICE)

          job
        end
    end
  end
end
