module OpenChain; module CustomHandler; module Ascena
  class AscenaCaInvoiceHandler

    def initialize custom_file
      @custom_file = custom_file
    end

    # Required for custom file processing
    def process user
      errors = []
      begin
        parse(@custom_file.attached.path)
      rescue AscenaCaInvoiceHandlerError => e
        load_errors(errors, e.message)
      rescue => e
        load_errors(errors, e.message)
        raise e
      ensure
        assign_message user, errors, @custom_file.attached_file_name 
      end
      nil
    end

    def can_view?(user)
      user.company.master?
    end

    def parse s3_path
      if File.extname(s3_path).downcase == ".csv"
        OpenChain::S3.download_to_tempfile('chain-io', s3_path) { |file| parse_csv file }
      else
        raise AscenaCaInvoiceHandlerError, "No CI Upload processor exists for #{File.extname(s3_path).downcase} file types."
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
          importer_id = get_importer_id "858053119RM0001"
          existing_invoice = CommercialInvoice.new(invoice_number: invoice_number, importer_id: importer_id)
        end

        CSV.parse(IO.read(csv_file).force_encoding("Windows-1252")) do |row|
          utf_row = row.map{ |field| field.presence ? field.encode("UTF-8", :invalid => :replace, :undef => :replace, replace: "?") : nil }
          existing_invoice = parse_invoice_line(utf_row, existing_invoice) unless counter.zero?
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
      CSV.foreach(csv_file) do |row|
        invoice_number = read_str(row[0]) if counter == 1  
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
      raise "Fenix ID #{fenix_id} not found!" unless co
      co.id
    end
   
   private

    def read_line csv_line
      result = {invoice_number: read_str(csv_line[0]), part_number: read_str(csv_line[7..9].join('-')), country_origin_code: read_str(csv_line[23]), 
                hts_code: read_str(csv_line[27].try(:delete, '.')), quantity: csv_line[29], value: csv_line[30]}
      raise AscenaCaInvoiceHandlerError, "Tariff number has wrong format!" unless result[:hts_code] =~ /^\d{10}$/
      raise AscenaCaInvoiceHandlerError, "Invoice number has wrong format!" unless result[:invoice_number] =~ /^[A-Z]{2}\d{9}$/
      result
    end

    def read_str v
      v.to_s.strip
    end

    def build_line parsed_hsh, existing_invoice
      cil = existing_invoice.commercial_invoice_lines.build(part_number: parsed_hsh[:part_number], 
                                                country_origin_code: convert_coo(parsed_hsh[:country_origin_code]), 
                                                quantity: parsed_hsh[:quantity], value: parsed_hsh[:value])
      cil.commercial_invoice_tariffs.build(hts_code: parsed_hsh[:hts_code])
      existing_invoice
    end

    def load_errors errors, message
      errors << "Unrecoverable errors were encountered while processing this file." << message
    end

    def assign_message user, errors, file_name 
      body = "Ascena Invoice File '#{file_name}' has finished processing."
      subject = "Ascena Invoice File Processing Completed"
      unless errors.blank?
        body += "<br>#{errors.join("<br>")}"
        subject += " With Errors"
      end
      
      user.messages.create(:subject=>subject, :body=>body)
    end
  
    class AscenaCaInvoiceHandlerError < StandardError
    end

  end
end; end; end
