require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_xml_support'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCommercialInvoiceGenerator
  include OpenChain::CustomHandler::Vandegrift::KewillShipmentXmlSupport
  include OpenChain::FtpFileSupport

  def generate_and_send_invoices file_number, commercial_invoices, opts = {}
    entry = CiLoadEntry.new(file_number, nil, [])
    commercial_invoices = Array.wrap(commercial_invoices)

    entry.customer = commercial_invoices.first.importer.alliance_customer_number
    commercial_invoices.each do |inv|
      invoice = CiLoadInvoice.new(inv.invoice_number, inv.invoice_date, [], nil, nil)
      entry.invoices << invoice

      inv.commercial_invoice_lines.each do |line|
        line.commercial_invoice_tariffs.each do |tar|
          l = CiLoadInvoiceLine.new
          l.po_number = line.po_number
          l.part_number = line.part_number
          l.pieces = line.quantity
          l.unit_price = line.unit_price
          l.country_of_origin = line.country_origin_code
          l.foreign_value = line.value
          l.first_sale = line.contract_amount
          l.department = line.department
          l.mid = line.mid

          l.hts = tar.hts_code
          l.quantity_1 = tar.classification_qty_1
          l.quantity_2 = tar.classification_qty_2
          # If gross weight is given in grams, we must convert it to KGS
          # If we're converting, always use 1 KG as the floor for weight.
          if opts[:gross_weight_uom].to_s.upcase == "G"
            l.gross_weight = (BigDecimal(tar.gross_weight.to_s) / BigDecimal("1000")).round(2)
            l.gross_weight = BigDecimal("1") if l.gross_weight < 1
          else
            l.gross_weight = tar.gross_weight
          end
          
          l.spi = tar.spi_primary
          
          invoice.invoice_lines << l
        end
      end
    end

    generate_and_send [entry]
  end

  def generate_and_send entries 
    Array.wrap(entries).each do |entry|
      if entry.invoices.length > 0
        doc = generate_entry_xml(entry, add_entry_info: false)

        Tempfile.open(["CI_Load_#{entry.file_number.to_s.gsub("/", "_")}_", ".xml"]) do |file|
          file.binmode
          write_xml doc, file
          file.rewind

          ftp_file file
        end
      end
    end
    nil
  # Just rescue any sort of fixed position generation error and re-raise it as a missing data error, that way callers only really
  # have one exception to deal with that covers all cases and don't need to know internals of how this class generates data
  rescue OpenChain::FixedPositionGenerator::FixedPositionGeneratorError => e
    raise MissingCiLoadDataError, e.message, e.backtrace
  end

  def ftp_credentials
    ecs_connect_vfitrack_net('kewill_edi/to_kewill')
  end

  # Generates a CI Load worksheet in the standard column layout
  def generate_xls ci_load_entries
    wb, sheet = XlsMaker.create_workbook_and_sheet "CI Load", ["File #", "Customer", "Invoice #", "Invoice Date", "Country of Origin", "Part # / Style", "Pieces", "MID", "Tariff #", "Cotton Fee (Y/N)", "Invoice Foreign Value", "Quantity 1", "Quantity 2", "Gross Weight", "PO #", "Cartons", "First Sale Amount", "NDC / MMV", "Department", "SPI", "Buyer Cust No", "Seller MID"]
    row_number = 0
    column_widths = []
    Array.wrap(ci_load_entries).each do |entry|
      row_number = add_xls_lines(sheet, row_number, entry, column_widths)
    end

    wb
  end

  def generate_xls_to_google_drive drive_path, ci_load_entries
    wb = generate_xls ci_load_entries

    tmp_file = Attachment.get_sanitized_filename(File.basename(drive_path, ".*"))
    Tempfile.open([tmp_file, File.extname(drive_path)]) do |t|
      t.binmode
      wb.write t
      t.flush
      t.rewind

      OpenChain::GoogleDrive.upload_file drive_path, t 
    end
    nil
  end

  private 
    def add_xls_lines sheet, last_row_number, entry, widths
      entry_data = []
      entry_data[0] = (entry.file_number.to_s.blank? || entry.file_number.to_s =~ /^0(\.0)?$/) ? nil : entry.file_number.to_s
      entry_data[1] = entry.customer.blank? ? nil : entry.customer

      invoices = Array.wrap(entry.invoices)
      if invoices.length > 0
        invoices.each do |invoice|
          invoice_data = []
          invoice_data[0] = invoice.invoice_number.blank? ? nil : invoice.invoice_number.to_s
          invoice_data[1] = invoice.invoice_date.nil? ? nil : invoice.invoice_date.to_date.strftime("%Y-%m-%d")

          lines = Array.wrap(invoice.invoice_lines)
          if lines.length > 0
            lines.each do |line|
              line_data = []
              line_data[0] = line.country_of_origin
              line_data[1] = line.part_number
              line_data[2] = line.pieces if line.pieces.to_f != 0
              line_data[3] = line.mid
              line_data[4] = line.hts
              line_data[5] = (line.cotton_fee_flag.to_s.to_boolean ? "Y" : "N") unless line.cotton_fee_flag.nil?
              line_data[6] = line.foreign_value if line.foreign_value.to_f != 0
              line_data[7] = line.quantity_1 if line.quantity_1.to_f != 0
              line_data[8] = line.quantity_2 if line.quantity_2.to_f != 0
              line_data[9] = line.gross_weight if line.gross_weight.to_f != 0
              line_data[10] = line.po_number
              line_data[11] = line.cartons.to_i if line.cartons.to_i != 0
              line_data[12] = line.first_sale if line.first_sale.to_f != 0
              line_data[13] = line.non_dutiable_amount if line.non_dutiable_amount.to_f != 0
              line_data[14] = line.department
              line_data[15] = line.spi
              line_data[16] = line.buyer_customer_number
              line_data[17] = line.seller_mid

              XlsMaker.add_body_row(sheet, last_row_number += 1, entry_data + invoice_data + line_data, widths)
            end
          else
            XlsMaker.add_body_row(sheet, last_row_number += 1, entry_data + invoice_data, widths)
          end
        end
      else
        XlsMaker.add_body_row(sheet, last_row_number += 1, entry_data, widths)
      end

      last_row_number
    end

end; end; end; end;