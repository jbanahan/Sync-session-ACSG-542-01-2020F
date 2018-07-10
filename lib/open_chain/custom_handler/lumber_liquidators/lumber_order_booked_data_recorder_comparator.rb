require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'

# Extracts the data from the snapshot that LL wants to store off as "milestone snapshot" data, as a point
# in time reference to what these values were when the order was booked (if the order is re-booked, the 
# the values will get updated).
#
# We're actually going to refer to "created" as when the line itself was booked.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderBookedDataRecorderComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    super(snapshot) && !snapshot.recordable.try(:booking_received_date).nil?
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    c = self.new
    c.record_data c.get_json_hash(old_bucket, old_path, old_version), c.get_json_hash(new_bucket, new_path, new_version)
  end

  # these are shipment snapshots (as we're tracking when booking lines are added to shipments here)
  def record_data old_snapshot, new_snapshot
    return unless booking_requested?(old_snapshot, new_snapshot)

    # We're going to record the data for every single order line on this booking (regardless of if it's already
    # been booked before or not).  LL wants the data recorded when the user hits the booking requested button,
    # and it's possible for a user to redo a booking.
    order_info = extract_order_info(new_snapshot)

    shipment_reference = mf(new_snapshot, :shp_ref)

    user = User.integration
    order_info.each_pair do |order_number, line_numbers|
      order = Order.where(order_number: order_number).first
      next unless order

      Lock.db_lock(order) do
        updated = false
        line_numbers.each do |line_number|
          line = order.order_lines.find {|l| l.line_number == line_number}
          if line
            record_order_line_data order, line
            updated = true
          end
        end

        order.create_snapshot user, nil, "PO Booked Data Recorder - Shipment # #{shipment_reference}"
      end
    end
    nil
  end

  private

    def booking_requested? old_snapshot, new_snapshot
      old_booking_requested = mf(old_snapshot, :shp_booking_received_date)
      new_booking_requested = mf(new_snapshot, :shp_booking_received_date)

      old_booking_requested != new_booking_requested
    end

    def extract_order_info snapshot
      booking_lines = json_child_entities(snapshot, "BookingLine")
      order_data = {}
      booking_lines.each do |line|
        order_number = mf(line, :bkln_order_number)
        order_line_number = mf(line, :bkln_order_line_number)

        order_data[order_number] ||= Set.new
        order_data[order_number] << order_line_number
      end

      order_data
    end

    def record_order_line_data order, order_line
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_article], order_line.product.try(:unique_identifier))
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_quantity], order_line.quantity)
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_hts], product_hts(order_line))
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_price_per_unit], order_line.price_per_unit)
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_total_price], order_line.total_cost)
      # Country of Origin comes from the Order Header for LL
      order_line.find_and_set_custom_value(cdefs[:ordln_po_booked_country_origin], order.custom_value(cdefs[:ord_country_of_origin]))

      order_line.save!
    end

    def product_hts order_line
      product = order_line.product
      hts = nil
      if product
        hts = product.hts_for_country(us).first
      end

      hts
    end

    def us
      @country ||= Country.where(iso_code: "US").first
    end

    def cdefs
      @cdefs ||= self.class.prep_custom_definitions [
        :ord_country_of_origin,
        :ordln_po_booked_article, :ordln_po_booked_quantity, :ordln_po_booked_hts, 
        :ordln_po_booked_price_per_unit, :ordln_po_booked_total_price, :ordln_po_booked_country_origin]
    end

    def find_order order_number
      @orders ||= Hash.new do |h, k|
        h[k] = Order.where(order_number: k).first
      end

      @orders[order_number]
    end

end; end; end; end;