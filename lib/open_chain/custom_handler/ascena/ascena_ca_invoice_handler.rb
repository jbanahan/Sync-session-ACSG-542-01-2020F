module OpenChain; module CustomHandler
  class AscenaCaInvoiceHandler
    FENIX_ID = "858053119RM0001"

    def initialize custom_file
      @custom_file = custom_file
    end

    # Required for custom file processing
    def process user
      errors = []
      begin
        errors = parse @custom_file.attached.path
      rescue
        errors << "Unrecoverable errors were encountered while processing this file.  These errors have been forwarded to the IT department and will be resolved."
        raise 
      ensure
        body = "Ascena Invoice File '#{@custom_file.attached_file_name}' has finished processing."
        subject = "Ascena Invoice File Processing Completed"
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

    def parse s3_path
      errors = []
      begin
        s3_to_db s3_path
      rescue => e
        errors << "Failed to process invoice due to the following error: '#{e.message}'."
      end
      errors
    end

    def s3_to_db s3_path
        if File.extname(s3_path).downcase == ".csv"
          OpenChain::S3.download_to_tempfile('chain-io', s3_path) { |file| parse_csv file }
        else
          raise "No CI Upload processor exists for #{File.extname(s3_path).downcase} file types."
        end
    end

    def parse_csv csv_file
      invoice_number = get_invoice_number csv_file
      existing_invoice = CommercialInvoice.where(invoice_number: invoice_number, entry_id: nil).first
      counter = 0

      CommercialInvoiceLine.transaction do
        if existing_invoice
          existing_invoice.commercial_invoice_lines.destroy_all
        else
          importer_id = get_importer_id FENIX_ID
          existing_invoice = CommercialInvoice.new(invoice_number: invoice_number, importer_id: importer_id)
        end

        CSV.foreach(csv_file, encoding: "Windows-1252:UTF-8") do |row|
          existing_invoice = parse_invoice_line row, existing_invoice unless counter.zero?
          counter += 1
        end
        existing_invoice.save!
      end
    end

    def parse_invoice_line csv_line, existing_invoice
      line = read_line csv_line
      build_line line, existing_invoice
    end

    def get_invoice_number csv_file
      counter = 0
      invoice_number = nil
      CSV.foreach(csv_file, encoding: "Windows-1252:UTF-8") do |row|
        invoice_number = row[0] if counter == 1  
        counter += 1
        break if counter > 1
      end
      invoice_number
    end

    def convert_coo coo
      (coo.length == 3 && coo[0] == 'U') ? "US" : coo
    end

    def get_importer_id fenix_id
      co = Company.where(fenix_customer_number: fenix_id).first
      raise "Fenix ID not found!" unless co
      co.id
    end
   
   private

    def read_line csv_line
      result = {invoice_number: csv_line[0], part_number: csv_line[7..9].join('-'), country_origin_code: csv_line[23], 
                hts_code: csv_line[27].delete('.'), quantity: csv_line[29], value: csv_line[30]}
      raise "Tariff number has wrong format!" unless result[:hts_code] =~ /^\d{10}$/
      raise "Invoice number has wrong format!" unless result[:invoice_number] =~ /^[A-Z]{2}\d{9}$/
      result
    end

    def build_line parsed_hsh, existing_invoice
      cil = existing_invoice.commercial_invoice_lines.build(part_number: parsed_hsh[:part_number], 
                                                country_origin_code: convert_coo(parsed_hsh[:country_origin_code]), 
                                                quantity: parsed_hsh[:quantity], value: parsed_hsh[:value])
      cil.commercial_invoice_tariffs.build(hts_code: parsed_hsh[:hts_code])
      existing_invoice
    end


  end
end; end