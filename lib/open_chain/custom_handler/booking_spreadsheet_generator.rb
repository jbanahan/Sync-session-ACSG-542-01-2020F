require 'open_chain/xl_client'
require 'open_chain/s3'

module OpenChain; module CustomHandler; class BookingSpreadsheetGenerator

  def self.generate user, shipment, shipment_lines
    self.new.generate_file(user, shipment, shipment_lines) do |file|
      yield file
    end
  end

  def generate_file user, shipment, shipment_lines
    generate_header_information user, shipment, shipment_lines
    generate_line_information user, shipment, shipment_lines

    path = s3_file_path(shipment)
    xl.save path, bucket: s3_destination_bucket
    OpenChain::S3.download_to_tempfile(s3_destination_bucket, path, original_filename: File.basename(path)) do |file|
      yield file
    end
  end

  def self.shipment_vendor_info shipment_lines
    # Get the first shipment line that has an order
    order = nil
    shipment_lines.each do |line|
      orders = line.respond_to?(:order) ? [line.order] : line.related_orders
      order = orders.first if orders.length > 0
      break if order
    end

    if order
      vendor = order.vendor
      ship_from = order.order_from_address
      return {vendor: vendor, vendor_address: ship_from}
    else
      return {}
    end
  end

  private

    def generate_header_information user, shipment, shipment_lines
      vendor_info = self.class.shipment_vendor_info(shipment_lines)
      add_company_info("A", 3, vendor_info[:vendor], vendor_info[:vendor_address]) unless vendor_info[:vendor].blank?
      add_company_info("G", 3, shipment.importer, nil) unless shipment.importer.blank?

      set_mf_cell "A", 9, :shp_fwd_name, shipment, user
      set_mf_cell "G", 9, :shp_requested_equipment, shipment, user
      set_mf_cell "A", 11, :shp_cargo_ready_date, shipment, user
      set_mf_cell "C", 11, :shp_mode, shipment, user
      set_mf_cell "E", 11, :shp_shipment_type, shipment, user
      port = shipment.first_port_receipt
      if port
        data = port.name
        if !port.unlocode.blank?
          data += " - #{port.unlocode}"
        end
        set_cell "G", 11, data
      end

      packages = mf_val(:shp_number_of_packages, shipment, user).to_s
      uom = mf_val(:shp_number_of_packages_uom, shipment, user)
      if !uom.blank?
        packages += " #{uom}"
      end

      set_cell "A", 13, packages
      set_mf_cell "C", 13, :shp_gross_weight, shipment, user
      set_mf_cell "E", 13, :shp_volume, shipment, user
      set_mf_cell "G", 13, :shp_lacey, shipment, user
      set_mf_cell "H", 13, :shp_hazmat, shipment, user
      set_mf_cell "I", 13, :shp_export_license_required, shipment, user
      set_mf_cell "K", 13, :shp_swpm, shipment, user

      set_marks_and_numbers mf_val(:shp_marks_and_numbers, shipment, user)
      nil
    end

    def generate_line_information user, shipment, shipment_lines
      starting_row = 21
      # The template we're using currently has 2 rows, the first has no bottom borders the second has bottom borders.  The one without border is the one
      # we want to copy down to accommodate all the lines we need to add.  We don't have a delete row xl_client command,
      # and I don't want to add one right now, so I'm going to just leave the second row (w/ the bottom border) blank for now
      # if we have less than 2 rows on the booking.
      if shipment_lines.length > 2
        (shipment_lines.length - 2).times { xl.copy_row(0, starting_row - 1, starting_row) }
      end
    
      shipment_lines.each_with_index do |line, x|
        generate_line(user, shipment, line, starting_row + x)
      end
      nil
    end

    def generate_line user, shipment, line, row
      if line.is_a?(BookingLine)
        generate_booking_line(user, line, row)
      elsif line.is_a?(ShipmentLine)
        generate_shipment_line(user, line, row)
      else
        raise "Unexpected shipment line type: #{line.class}."
      end
    end

    def generate_booking_line user, line, row
      set_cell "A", row, line.line_number
      set_cell "B", row, line.order.try(:customer_order_number)
      set_cell "D", row, line.order_line.try(:line_number)
      set_cell "E", row, line.product.try(:unique_identifier)
      set_cell "G", row, line.quantity
      set_cell "H", row, line.order_line.try(:unit_of_measure)
      set_cell "I", row, line.variant.try(:variant_identifier)
    end

    def generate_shipment_line user, line, row
      order_line = line.order_lines.first
      order = order_line.try(:order)
      product = order_line.try(:product)

      set_cell "A", row, line.line_number
      set_cell "B", row, order.try(:customer_order_number)
      set_cell "D", row, order_line.try(:line_number)
      set_cell "E", row, product.try(:unique_identifier)
      set_cell "G", row, line.quantity
      set_cell "H", row, order_line.try(:unit_of_measure)
      set_cell "I", row, line.variant.try(:variant_identifier)
    end

    def add_company_info column, starting_row, company, address
      address_data = [company.try(:name)]

      if address
        address_data.push *address.full_address_array(skip_name: true)
      end
      
      address_data.each_with_index do |v, x|
        # There's only 5 rows allotted for address, so don't let it overflow
        break if x > 4
        set_cell(column, (starting_row + x), v)
      end
      nil
    end

    def set_mf_cell col, row, uid, obj, user
      set_cell col, row, mf_val(uid, obj, user)
    end

    def mf_val(uid, obj, user)
      field = ModelField.find_by_uid(uid)
      val = field.process_export(obj, user, true)
      if :boolean == field.data_type
        val = (val === true ? "Y" : "N")
      elsif :date == field.data_type
        val = (val ? val.strftime("%Y-%m-%d") : nil)
      elsif :datetime == field.data_type
        val = (val ? val.in_time_zone(user.time_zone.blank? ? "America/New_York" : user.time_zone).strftime("%Y-%m-%d") : nil)
      end

      val
    end

    def set_cell col, row, value
      xl.set_cell(0, (row - 1), col, value) unless value.nil?
    end

    def set_marks_and_numbers value
      # Pull out any lines that are just blank lines
      marks = value.split("\n").reject {|l| l.strip.blank? }

      # If we need more than 5 M&N rows, then there's probably room on the template 
      # to create another cell at G14 for them to continue at.  For now, we'll just leave this as is.
      starting_row = 15
      marks.each_with_index do |mark, x|
        break if x > 4
        set_cell "A", (starting_row + x), mark
      end
    end

    def xl
      @xl_client ||= xl_client
      @xl_client
    end

    def xl_client
      OpenChain::XLClient.new s3_template_path, bucket: s3_template_bucket
    end

    def s3_template_bucket
      Rails.configuration.paperclip_defaults[:bucket]
    end

    def s3_template_path
      "#{MasterSetup.get.uuid}/templates/shipment_info.xlsx"
    end

    def s3_destination_bucket
      "chainio-temp"
    end

    def s3_file_path shipment
      "#{MasterSetup.get.uuid}/shipment/#{shipment.reference}.xlsx"
    end

end; end; end