require 'open_chain/custom_handler/vandegrift/fenix_invoice_810_generator_support'

module OpenChain; module CustomHandler; class FenixNdInvoiceGenerator
  include OpenChain::CustomHandler::Vandegrift::FenixInvoice810GeneratorSupport

  # If you extend this class you may want to extend the following methods to provide custom data to the output mappings:
  # invoice_header_map, invoice_detail_map
  #
  # Additional optional method implementations:
  # rollup_detail_lines_by -
  # Defining this method allows you to specify which detail level fields to group individual lines together by (summing the piece counts of those lines that are grouped together).
  # The return value from this method should be an array containing the symbol names to roll up detail lines by - all detail fields are valid to use here except quantity.

  def generate_file id_or_invoice
    invoice = id_or_invoice.is_a?(CommercialInvoice) ? id_or_invoice : CommercialInvoice.find(id_or_invoice)

    if invoice
      header_map = invoice_header_map
      detail_map = invoice_detail_map
      rollup_by = (self.respond_to? :rollup_by) ? rollup_by : []

      #File should use \r\n newlines and be straight ASCII chars
      #Ack: MRI Ruby 1.9 has a bug in tempfile that doesn't allow you to use string :mode option here
      importer_tax_id = invoice.importer.try(:fenix_customer_identifier)
      invoice_number = invoice.invoice_number

      Tempfile.open(["#{importer_tax_id}_fenix_invoice_#{invoice_number.to_s.gsub("/", "_")}_",'.txt'], {:external_encoding =>"ASCII"}) do |t|
        # Write out the header information
        write_line t, header_format, invoice
        t << "\r\n"
        
        line_count = 0
        invoice.commercial_invoice_lines.each do |line|
          line.commercial_invoice_tariffs.each do |tariff|
            if rollup_by.blank?
              write_line t, detail_format, invoice, line, tariff
              t << "\r\n"
              line_count += 1
            else
              # For outputs where we're rolling up the lines, we'll basically have to buffer the lines generated in memory and then write them out after rolling them together.
              raise "Rolling up invoice detail lines is not yet implemented."
            end
          end
        end
        t.flush
        t.rewind

        if line_count > 999
          raise "Invoice # #{invoice.invoice_number} generated a Fenix invoice file containing #{line_count} lines.  Invoice's over 999 lines are not supported and must have detail lines consolidated or the invoice must be split into multiple pieces."
        end

        yield(t) if block_given?
      end
    end
  end

  def generate_and_send id, sync_record: nil
    generate_file(id) do |file|
      if sync_record
        ftp_sync_file file, sync_record, ftp_connection_info
      else
        ftp_file file, ftp_connection_info
      end
      
    end
  end
  

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
  # You can override this method and use the hash returned as a merge point for any customer specific data points.

  def invoice_header_map
    {
      :record_type => "H",
      :invoice_number => lambda {|i| i.invoice_number.blank? ? "VFI-#{i.id}" : i.invoice_number },
      :invoice_date => lambda {|i| i.invoice_date },
      :country_origin_code => lambda {|i| i.country_origin_code},
      # There's no actual invoice field for this value, but I don't know when this value would ever not be CA since we're sending to Fenix
      :country_ultimate_destination => "CA",
      :currency => lambda {|i| i.currency},
      :number_of_cartons => lambda {|i| (i.total_quantity_uom =~ /CTN/i) ? i.total_quantity : BigDecimal.new("0")},
      :gross_weight => lambda {|i| i.gross_weight ? i.gross_weight : 0},
      :total_units => lambda {|i| number_of_units(i)},
      :total_value => lambda {|i| calculate_invoice_value(i)},
      :shipper => lambda {|i| i.vendor },
      :consignee => lambda {|i| i.consignee },
      :po_number => lambda {|i| i.commercial_invoice_lines.first.try(:po_number) },
      :mode_of_transportation => "2",
      # We should be sending just "GENERIC" as the importer name in the default case
      # which then will force the ops people to associate the importer account manually as the pull them
      # into the system.  This partially needs to be done based on the way edi in feninx handling is done on a 
      # per file directory basis.  This avoids extra setup when we just want to pull a generic invoice into the system.
      :importer => lambda { |i| Company.new name: "GENERIC" },
      :reference_identifier => lambda {|i| i.commercial_invoice_lines.select {|l| !l.customer_reference.blank?}.first.try(:customer_reference)},
      :customer_name => lambda {|i| i.importer.try(:name)},
      :scac => lambda {|i| i.master_bills_of_lading.blank? ? nil : i.master_bills_of_lading[0, 4] },
      :master_bill => lambda {|i| i.master_bills_of_lading.blank? ? "Not Available" : i.master_bills_of_lading }
    }
  end

  # invoice_detail_map - 
  # This method works identical to invoice_header_map with the following fields:
  # This method should return a mapping of the fields utilized to send detail level invoice data
  # These fields are: :part_number, :country_origin_code, :hts_code, :tariff_description, :quantity, :unit_price, , :po_number
  # The values passed to lamdas defined in the map are invoice, line, and tariff.
  #
  # You can override this method and use the hash returned as a merge point for any customer specific data points.
  def invoice_detail_map
    {
      :record_type => "D",
      :part_number => lambda {|i, line, tariff| line.part_number},
      :country_origin_code => lambda {|i, line, tariff| line.country_origin_code},
      # Operations asked us to send a value that would easily let them know the HTS value was
      # invalid for cases where there's no HTS number we could find in the value.  Randy
      # suggested that a value of 0 would always trip any validations and it would 
      # force them to address each invalid line if we did this.
      :hts_code => lambda {|i, line, tariff| (tariff.try(:hts_code).blank?) ? "0" : tariff.hts_code},
      :tariff_description => lambda {|i, line, tariff| tariff.try(:tariff_description)},
      :quantity => lambda {|i, line, tariff| line.quantity},
      :unit_price => lambda {|i, line, tariff| line.unit_price},
      :po_number => lambda {|i, line, tariff| line.po_number},
      :tariff_treatment => lambda {|i, line, tariff| tariff.try(:tariff_provision).blank? ? "2" : tariff.tariff_provision }
    }
  end

  def invoice_party_map
    {
      # Fenix expects at least a name for all companies, so in the cases where we don't have one we need to throw
      # in something.
      name: lambda { |c| c.try(:name).presence || "GENERIC" },
      name_2: lambda { |c| c.try(:name_2) },
      address_1: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:line_1) },
      address_2: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:line_2) },
      city: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:city) },
      state: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:state) },
      postal_code: lambda {|c| Array.wrap(c.try(:addresses)).first.try(:postal_code) }
    }
  end

  def self.generate invoice_id
    self.new.generate_and_send invoice_id
  end

  # If no header level invoice_value is set, sums the values from the line level.  If any line
  # does not have BOTH a quantity and unit_price, then the valuation is abandonded and a value
  # of zero is returned.
  def calculate_invoice_value invoice
    value = BigDecimal.new("0.00")

    # If there's any value at all set at the header level, use that..otherwise
    # attempt to sum the invoice lines.
    if invoice.invoice_value && invoice.invoice_value != BigDecimal.new("0")
      value = invoice.invoice_value
    else
      sum_value = BigDecimal.new("0.00")
      invalid = false
      invoice.commercial_invoice_lines.each do |line|
        # We have to abondon the summing if any line is missing a quantity or unit price value
        # since that's an error and will throw off the header calculation.  We'd rather ops
        # have to calculate out the value then proceed with an invalid valuation in this case.
        if line.quantity && line.unit_price
          sum_value += (line.quantity * line.unit_price)
        else
          invalid = true
          break
        end
      end
      value = sum_value unless invalid
    end

    value
  end

  private

    def number_of_units invoice
      sum = BigDecimal.new "0"
      invoice.commercial_invoice_lines.each do |line|
        if line.quantity
          sum += line.quantity
        else
          sum = nil
          break
        end
      end
      sum ? sum : BigDecimal.new("0")
    end

end; end; end