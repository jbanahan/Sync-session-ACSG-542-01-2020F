module OpenChain; module CustomHandler; module LumberLiquidators; class LumberFactoryPackCsvGenerator

  def self.generate_csv shipment
    sync_count = shipment.sync_records.where(trading_partner: 'Factory Pack Declaration').length
    current_date = ActiveSupport::TimeZone['UTC'].now
    vendor_address = get_vendor_address shipment

    headers = ['Version', 'Document Created Date Time', 'Shipper Name', 'Shipper Address', 'Shipper City',
               'Shipper State', 'Shipper Postal Code', 'Shipper Country', 'Carrier Booking Number', 'Vessel', 'Voyage',
               'Port of Loading', 'Port of Delivery', 'Shipment Plan Number', 'Container Number', 'Container Size',
               'Seal Number', 'Container Pickup Date', 'Container Return Date', 'PO Number', 'Item', 'Line Item ID',
               'Description', 'Cartons', 'Pieces', 'CBM', 'Gross Weight KGS', 'Remark', 'Container Total Cartons',
               'Container Total Pieces', 'Container Total CBM', 'Container Total KGS']

    CSV.generate() do |csv|
      csv << headers
      line_number = 1
      shipment.shipment_lines.each do |shipment_line|
        shipment_line.order_lines.each do |order_line|
          row = []
          row << (sync_count > 0 ? 'Revised' : 'Original')
          row << format_date(current_date, true)
          row << shipment.vendor.try(:name)
          row << vendor_address.try(:line_1)
          row << vendor_address.try(:city)
          row << vendor_address.try(:state)
          row << vendor_address.try(:postal_code)
          row << vendor_address.try(:country).try(:iso_code)
          row << shipment.booking_number
          row << shipment.booking_vessel
          row << shipment.booking_voyage
          row << shipment_line.try(:container).try(:port_of_loading).try(:unlocode)
          row << shipment_line.try(:container).try(:port_of_delivery).try(:unlocode)
          row << shipment.importer_reference
          row << shipment_line.try(:container).try(:container_number)
          row << shipment_line.try(:container).try(:container_size)
          row << shipment_line.try(:container).try(:seal_number)
          row << format_date(shipment_line.try(:container).try(:container_pickup_date), false)
          row << format_date(shipment_line.try(:container).try(:container_return_date), false)
          row << order_line.order.order_number
          # Strip zero-padding from the item number.  Allport's system can't handle it.
          row << order_line.product.unique_identifier.sub(/^0+/, "")
          row << order_line.line_number
          row << order_line.product.name
          row << shipment_line.carton_qty
          row << shipment_line.quantity
          row << shipment_line.cbms
          row << shipment_line.gross_kgs
          # Remark field is intentionally left blank.
          row << nil
          # The totals fields represent all lines on the container, including the current line.
          container_lines = get_container_lines shipment, shipment_line.container
          row << get_container_total_cartons(container_lines)
          row << get_container_total_pieces(container_lines)
          row << get_container_total_cbms(container_lines)
          row << get_container_total_kgs(container_lines)
          csv << row
        end
      end
    end
  end

  class << self
    private
      def get_vendor_address shipment
        v_address = nil
        if shipment.vendor
          v_address = Address.where(company_id: shipment.vendor_id, name: "Corporate").first
        end
        v_address
      end

      def format_date d, include_time
        d ? d.strftime("%Y%m%d#{include_time ? '%H%M%S' : ''}") : nil
      end

      def get_container_lines shipment, container
        container_lines = []
        if container
          container_lines = shipment.shipment_lines.where(container_id:container.id)
        end
        container_lines
      end

      def get_container_total_cartons container_lines
        total = 0
        container_lines.each do |cont_line|
          total += (cont_line.carton_qty ? cont_line.carton_qty : 0)
        end
        total
      end

      def get_container_total_pieces container_lines
        total = 0
        container_lines.each do |cont_line|
          total += (cont_line.quantity ? cont_line.quantity : 0)
        end
        total
      end

      def get_container_total_cbms container_lines
        total = 0
        container_lines.each do |cont_line|
          total += (cont_line.cbms ? cont_line.cbms : 0)
        end
        total
      end

      def get_container_total_kgs container_lines
        total = 0
        container_lines.each do |cont_line|
          total += (cont_line.gross_kgs ? cont_line.gross_kgs : 0)
        end
        total
      end
  end

end;end;end;end