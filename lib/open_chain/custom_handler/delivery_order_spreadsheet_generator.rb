require 'open_chain/xl_client'
require 'open_chain/s3'

module OpenChain; module CustomHandler; class DeliveryOrderSpreadsheetGenerator
  include ActionView::Helpers::NumberHelper

  DELIVERY_ORDER_GENERATORS ||= {
    'PVH' => ['OpenChain::CustomHandler::Pvh::PvhDeliveryOrderSpreadsheetGenerator', 'open_chain/custom_handler/pvh/pvh_delivery_order_spreadsheet_generator']
  }

  DeliveryOrderData ||= Struct.new(:instruction_provided_by, :date, :vfi_reference, :vessel_voyage, :importing_carrier, :freight_location, :port_of_origin,
                               :bill_of_lading, :arrival_date, :last_free_day, :do_issued_to, :for_delivery_to, :special_instructions, :no_cartons, :weight,
                               :prepaid_collect, :agents_for, :body, :tab_title)

  def self.generate_and_send_delivery_orders user_id, entry_id
    # This method is meant to be called asyncronously, hence the ids being passed
    user = User.where(id: user_id).first
    entry = Entry.where(id: entry_id).first
    return unless entry && user

    generator = get_generator(entry.customer_number)
    generator_data = generator.generate_delivery_order_data entry
    files = generator.generate_delivery_order_spreadsheets generator_data
    generator.send_delivery_order user, entry.broker_reference, files
  end

  def self.get_generator customer_number
    generator_config = DELIVERY_ORDER_GENERATORS[customer_number]
    if generator_config
      if generator_config[0].is_a? String
        # Require the generator class, then put the actual class into the config, so we don't have to require it again
        # This is kind of a way to store all the implementing classes in this particular class (so we have the full list right here)
        #  and then not have to do anything additionally funky to make sure they get loaded in the right order (.ie require AFTER this class, etc)
        require generator_config[1]
        generator_config[0] = generator_config[0].constantize
      end
      generator = generator_config[0].new
    else
      # Use the current class as the default if no generator is setup
      generator = self.new
    end

    generator
  end


  def generate_delivery_order_data entry
    del = DeliveryOrderData.new

    del.date = Time.zone.now.in_time_zone("America/New_York").to_date
    del.vfi_reference = entry.broker_reference
    del.vessel_voyage = "#{entry.vessel} V#{entry.voyage}"
    del.freight_location = entry.location_of_goods_description
    del.port_of_origin = entry.lading_port.try(:name)
    del.importing_carrier = entry.carrier_code
    master_bills = entry.master_bills_of_lading.to_s.split("\n")
    del.bill_of_lading = (master_bills.size > 1) ? "MULTIPLE - SEE BELOW" : master_bills.first
    del.arrival_date = entry.arrival_date ? entry.arrival_date.in_time_zone("America/New_York").to_date : nil
    del.no_cartons = "#{entry.total_packages} #{entry.total_packages_uom}"
    del.weight = "#{number_with_precision((BigDecimal(entry.gross_weight.to_s) * BigDecimal("2.20462")), precision: 0) } LBS" if entry.gross_weight
    del.body = ["PORT OF DISCHARGE: #{entry.unlading_port.try(:name)}"]
    del.tab_title = entry.broker_reference

    [del]
  end

  def generate_delivery_order_spreadsheets delivery_orders
    tab_count = 0
    Array.wrap(delivery_orders).each do |del|
      # Generate a new tab on the spreadsheet for each DO, the first sheet is
      # the template.
      tab_name = del.tab_title.presence || "Sheet #{tab_count + 1}"
      tab_index = clone_template_page tab_name
      tab_count += 1

      set_cell tab_index, "K", 6, del.date
      set_cell tab_index, "M", 6, del.vfi_reference

      set_multiple_vertical_cells tab_index, "F", 7, del.instruction_provided_by, 4
      set_cell tab_index, "B", 10, del.vessel_voyage
      set_cell tab_index, "B", 12, del.importing_carrier
      set_cell tab_index, "F", 12, del.freight_location
      set_cell tab_index, "L", 12, del.port_of_origin
      set_cell tab_index, "B", 14, del.bill_of_lading
      set_cell tab_index, "F", 14, del.arrival_date
      set_cell tab_index, "H", 14, del.last_free_day
      set_cell tab_index, "J", 14, del.do_issued_to
      set_multiple_vertical_cells tab_index, "B", 16, del.for_delivery_to, 5
      set_multiple_vertical_cells tab_index, "I", 16, del.special_instructions, 5
      set_cell tab_index, "B", 22, del.no_cartons
      set_cell tab_index, "M", 22, del.weight

      set_multiple_vertical_cells tab_index, "B", 23, del.body, 1000
    end
    
    # Clear the primary "template" tab from the spreadsheet - which will always be index 0
    if Array.wrap(delivery_orders).length > 0
      xl.delete_sheet 0
      path = s3_file_path(Array.wrap(delivery_orders))
      xl.save path, bucket: s3_destination_bucket
      [{bucket: s3_destination_bucket, path: path}]
    else
      []
    end
    
  end

  def send_delivery_order user, file_number, delivery_order_files
    files = []
    begin
      files = delivery_order_files.map {|f| OpenChain::S3.download_to_tempfile(f[:bucket], f[:path], original_filename: File.basename(f[:path])) }
      if files.length == 0
        body = "No Delivery Orders were generated for File # #{file_number}."
      else
        body = "Attached #{files.size > 1 ? "are" : "is"} the Delivery Order #{"file".pluralize(files.size)} for File # #{file_number}."
      end
      
      OpenMailer.send_simple_html(user.email, "Delivery Order for File # #{file_number}", body,files).deliver!
    ensure
      files.each {|f| f.close! unless f.closed? }
    end
  end

  private 
    def set_cell tab, col, row, value
      xl.set_cell(tab, (row - 1), col, value) unless value.nil?
    end

    def clone_template_page tab_name
      xl.clone_sheet 0, tab_name
    end

    def set_multiple_vertical_cells tab_index, col, starting_row, values, max_rows
      counter = -1
      Array.wrap(values).each do |value|
        next if value.nil?

        set_cell tab_index, col, (starting_row + (counter += 1)), value
        break if counter >= max_rows
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
      "#{MasterSetup.get.uuid}/templates/delivery_order.xlsx"
    end

    def s3_destination_bucket
      "chainio-temp"
    end

    def s3_file_path delivery_orders
      del = delivery_orders.first
      "#{MasterSetup.get.uuid}/delivery_orders/#{del.vfi_reference}.xlsx"
    end
end; end; end