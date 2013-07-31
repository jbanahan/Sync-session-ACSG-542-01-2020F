require 'tempfile'
require 'bigdecimal'
require 'open_chain/ftp_file_support'

module OpenChain; module CustomHandler
  module FenixInvoiceGenerator
    include OpenChain::FtpFileSupport

    # If you include this module you must implement the following methods:
    #
    # invoice_header_map - 
    # This method should return a mapping of the fields utilized to send header level invoice data to a lambda, method name, or a constant object
    # lambdas will be called using instance_exec giving access to local methods and objects returned will be
    # used directly as an output value.
    #
    # The mapping field values are: :invoice_number, :invoice_date, :country_origin_code, :country_ultimate_destination, :currency, 
    # :number_of_cartons, :gross_weight, :total_units, :total_charges, :shipper, :consignee, :importer, :po_number, :mode_of_transportation
    #
    # Shipper, Consignee and Importer are expected to return hashes consisting of any or all of the following keys:
    # :name, :name_2, :address_1, :address_2, :city, :state, :postal_codereturns a mapping of 
    # 
    # You can use the hash returned from default_invoice_header_map as a merge point for any customer specific data points.
    #
    #
    # invoice_detail_map - 
    # This method works identical to invoice_header_map with the following fields:
    # This method should return a mapping of the fields utilized to send detail level invoice data
    # These fields are: :part_number, :country_origin_code, :hts_code, :tariff_description, :quantity, :unit_price, , :po_number
    # The values passed to lamdas defined in the map are invoice, line, and tariff.
    #
    # You can use the hash returned from default_invoice_detail_map as a merge point for any customer specific data points.
    #
    # fenix_customer_code - return the customer code for the specific customer we're sending data for
    #
    # Additional optional method implementations:
    # rollup_detail_lines_by -
    # Defining this method allows you to specify which detail level fields to group individual lines together by (summing the piece counts of those lines that are grouped together).
    # The return value from this method should be an array containing the symbol names to roll up detail lines by - all detail fields are valid to use here except quantity.

    PARTY_OUTPUT_FORMAT ||= [
      {:field => :name, :length => 50},
      {:field => :name_2, :length => 50},
      {:field => :address_1, :length => 50},
      {:field => :address_2, :length => 50},
      {:field => :city, :length => 50},
      {:field => :state, :length => 50},
      {:field => :postal_code, :length => 50}
    ]

    HEADER_OUTPUT_FORMAT ||= [
      {:field => :invoice_number, :length => 25},
      {:field => :invoice_date, :length => 10},
      {:field => :country_origin_code, :length => 10},
      {:field => :country_ultimate_destination, :length => 10},
      {:field => :currency, :length => 4},
      {:field => :number_of_cartons, :length => 15},
      {:field => :gross_weight, :length => 15},
      {:field => :total_units, :length => 15},
      {:field => :total_value, :length => 15},
      # These subformat fields' data should be suplied by the mapping via a hash returned by the mappings of these field's names (:shipper, :consignee, :importer)
      {:field => :shipper, :subformat => FenixInvoiceGenerator::PARTY_OUTPUT_FORMAT},
      {:field => :consignee, :subformat => FenixInvoiceGenerator::PARTY_OUTPUT_FORMAT},
      {:field => :importer, :subformat => FenixInvoiceGenerator::PARTY_OUTPUT_FORMAT},
      {:field => :po_number, :length => 50},
      {:field => :mode_of_transportation, :length => 1},
    ]

    DETAIL_OUTPUT_FORMAT ||= [
      {:field => :part_number, :length => 50},
      {:field => :country_origin_code, :length => 10},
      {:field => :hts_code, :length => 12},
      {:field => :tariff_description, :length => 50},
      {:field => :quantity, :length => 15},
      {:field => :unit_price, :length => 15},
      {:field => :po_number, :length => 50}
    ]

    def generate_file id
      invoice = CommercialInvoice.find id

      if invoice
        header_map = invoice_header_map
        detail_map = invoice_detail_map
        rollup_by = (self.respond_to? :rollup_by) ? rollup_by : []

        #File should use \r\n newlines and be straight ASCII chars
        #Ack: MRI Ruby 1.9 has a bug in tempfile that doesn't allow you to use string :mode option here
        t = Tempfile.new(["#{fenix_customer_code()}_fenix_invoice",'.txt'], {:external_encoding =>"ASCII"})
        begin
          # Write out the header information
          write_fields t, "H", FenixInvoiceGenerator::HEADER_OUTPUT_FORMAT, header_map, invoice

          line_count = 0
          invoice.commercial_invoice_lines.each do |line|
            line.commercial_invoice_tariffs.each do |tariff|
              if rollup_by.blank?
                write_fields t, "D", FenixInvoiceGenerator::DETAIL_OUTPUT_FORMAT, detail_map, invoice, line, tariff
                line_count += 1
              else
                # For outputs where we're rolling up the lines, we'll basically have to buffer the lines generated in memory and then write them out after rolling them together.
                raise "Rolling up invoice detail lines is not yet implemented."
              end
            end
          end
          t.flush

          if line_count > 999
            raise "Invoice # #{invoice.invoice_number} generated a Fenix invoice file containing #{line_count} lines.  Invoice's over 999 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
          end
        rescue Exception
          t.close!
          raise
        end
        t
      end
    end

    def generate_and_send id
      file = generate_file id
      if file
        ftp_file file
      end
    end

    def ftp_credentials 
      {:server=>'ftp2.vandegriftinc.com',:username=>'VFITRack',:password=>'RL2VFftp',:folder=>'to_ecs/fenix_invoices',:remote_file_name=>"#{fenix_customer_code()}_INV_#{Time.now.to_i}.txt"}
    end

    def default_invoice_header_map
      {
        :invoice_number => lambda {|i| i.invoice_number},
        :invoice_date => lambda {|i| i.invoice_date ? i.invoice_date.strftime("%Y%m%d") : ""},
        :country_origin_code => lambda {|i| i.country_origin_code},
        # There's no actual invoice field for this value, but I don't know when this value would ever not be CA since we're sending to Fenix
        :country_ultimate_destination => "CA",
        :currency => lambda {|i| i.currency},
        :number_of_cartons => lambda {|i| (i.total_quantity_uom =~ /CTN/i) ? i.total_quantity : BigDecimal.new("0")},
        :gross_weight => lambda {|i| i.gross_weight},
        :total_units => lambda {|i| i.commercial_invoice_lines.inject(BigDecimal.new("0.00")) {|sum, line| line.quantity ? (sum + line.quantity) : sum}},
        :total_value => lambda {|i| i.invoice_value ? i.invoice_value : BigDecimal.new("0")},
        :shipper => lambda {|i| convert_company_to_hash(i.vendor)},
        :consignee => lambda {|i| convert_company_to_hash(i.consignee)},
        :importer => lambda {|i| convert_company_to_hash(i.importer)},
        :po_number => lambda {|i| i.commercial_invoice_lines.first.nil? ? "" : i.commercial_invoice_lines.first.po_number},
        :mode_of_transportation => "2"
      }
    end

    def default_invoice_detail_map
      {
        :part_number => lambda {|i, line, tariff| line.part_number},
        :country_origin_code => lambda {|i, line, tariff| line.country_origin_code},
        :hts_code => lambda {|i, line, tariff| tariff.hts_code},
        :tariff_description => lambda {|i, line, tariff| tariff.tariff_description},
        :quantity => lambda {|i, line, tariff| line.quantity},
        :unit_price => lambda {|i, line, tariff| line.unit_price},
        :po_number => lambda {|i, line, tariff| line.po_number}
      }
    end

    def convert_company_to_hash company, address = nil
      h = {}

      # Pre-populate all the necessary hash keys with blank values
      # Ensures, regardless of if there's a company and address, we get spacings the header line for the fields
      PARTY_OUTPUT_FORMAT.each {|x| h[x[:field]] = ""}

      if company
        h[:name] = company.name
        h[:name_2] = company.name_2

        if address.nil? && company.addresses.length > 0
          # Just use the first address
          address = company.addresses.first
        end
        
        if address
          h[:address_1] = address.line_1
          h[:address_2] = address.line_2
          h[:city] = address.city
          h[:state] = address.state
          h[:postal_code] = address.postal_code
        end
      end
      
      h
    end

    private
      def mapping_value lamda_or_method_name, *args
        value = nil
        if lamda_or_method_name
          if lamda_or_method_name.is_a? Proc
            # Use self as the context for the lamda execution so any helper methods
            # for formatting, etc are available to use by the lamda (especially important here is allowing convert_company_to_hash to be accessible)
            value = instance_exec *args, &lamda_or_method_name
          else
            # We'll assume anything else returned from the mapping is a "constant" value
            value = lamda_or_method_name
          end
        end
        value 
      end

      def format_for_output field, value
        value = value.nil? ? "" : value.to_s

        max_len = field[:length]
        if value.length > max_len
          value = value[0..(max_len - 1)]
        elsif value.length < max_len
          value = value.ljust(max_len)
        end

        # We need to make sure we're only exporting ASCII chars so add a ? for any character outside the ASCII range
        value.encode("ASCII", {:invalid => :replace, :undef => :replace, :replace => "?"})
      end

      def write_fields file, field_type, output_format_fields, data_mapping, *args
        file << field_type
        output_format_fields.each do |format|
          value = mapping_value(data_mapping[format[:field]], *args)
          # We're expecting some form of hash returned here for the subformat fields
          if format[:subformat]
            format[:subformat].each do |subformat|
              file << format_for_output(subformat, value[subformat[:field]])
            end
          else
            file << format_for_output(format, value)
          end
          
        end

        # The mapping is looking for newlines as CRLF
        file << "\r\n"
      end
  end
end; end