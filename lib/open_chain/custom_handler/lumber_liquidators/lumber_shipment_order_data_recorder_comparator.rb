require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'

# Extracts the data from the snapshot that LL wants to store off as "milestone snapshot" data, as a point
# in time reference to what these values were when the order was booked (if the order is re-booked, the 
# the values will get updated).
#
# We're actually going to refer to "created" as when the line itself was booked.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberShipmentOrderDataRecorderComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    c = self.new
    c.record_data c.get_json_hash(old_bucket, old_path, old_version), c.get_json_hash(new_bucket, new_path, new_version)
  end

  def record_data old_hash, new_hash
    new_booking_lines = extract_new_booking_lines(old_hash, new_hash)

    # If any booking lines were added, then we need to update the orders associated with them regardless of whether the
    # shipment data changed or not.
    changes = mapped_changes(old_hash, new_hash)
    return unless changes.size > 0 || new_booking_lines.length > 0

    shipment_reference = mf(new_hash, :shp_ref)

    user = User.integration
    if new_booking_lines.length > 0
      new_data = shipment_order_data(new_hash)
      update_order_number_on_booking_lines(new_booking_lines, new_data, user, shipment_reference)
    end

    # Because the order update method utilized below will only update orders if the data changes, we don't have to worry about
    # excluding orders that may have already been updated due to a new booking line being added that references an order
    # already on the shipment.
    if changes.size > 0
      update_order_number_on_booking_lines(json_child_entities(new_hash, "BookingLine"), changes, user, shipment_reference)
    end

    nil
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [
      :ord_shipment_reference,
      :ord_shipment_cargo_ready_date, :ord_shipment_booking_requested_date, :ord_shipment_booking_number, 
      :ord_shipment_sent_to_carrier_date, :ord_shipment_booking_confirmed_date, :ord_shipment_booking_cutoff_date]
  end

  def field_mapping
    {
      shp_ref: {uid: :ord_shipment_reference}, shp_cargo_ready_date: {uid: :ord_shipment_cargo_ready_date}, shp_booking_received_date: {uid: :ord_shipment_booking_requested_date, data_type: :date},
      shp_booking_number: {uid: :ord_shipment_booking_number}, shp_booking_approved_date: {uid: :ord_shipment_sent_to_carrier_date, data_type: :date}, 
      shp_booking_confirmed_date: {uid: :ord_shipment_booking_confirmed_date, data_type: :date}, shp_booking_cutoff_date: {uid: :ord_shipment_booking_cutoff_date, data_type: :date}
    }
  end

  def mapped_changes old_hash, new_hash
    changes = changed_fields(old_hash, new_hash, [:shp_ref, :shp_cargo_ready_date, :shp_booking_received_date, :shp_booking_number, 
      :shp_booking_approved_date, :shp_booking_confirmed_date, :shp_booking_cutoff_date])

    map = {}
    order_fields = field_mapping
    changes.each_pair do |k, v|
      map[order_fields[k][:uid]] = map_value(k, order_fields[k], new_hash)
    end

    map
  end

  def shipment_order_data data
    order_fields = field_mapping
    map = {}
    order_fields.each_pair do |k, hsh|
      map[hsh[:uid]] = map_value(k, hsh, data)
    end

    map
  end

  def map_value shipment_uid, mapping, shipment_data
    value = mf(shipment_data, shipment_uid)
    # All datetimes should be parsed from the snapshot as ActiveSupport::TimeWithZone objects
    # If we're converting to order values that should be dates, we should be converting them.
    # We're going to convert the dates to Eastern Time Zone first before to_date'ing them 
    # as this is how Lumber would view these dates and the order version of hte dates are for Lumber.
    if value.respond_to?(:in_time_zone) && mapping[:data_type] == :date
      tz = mapping[:timezone].presence || "America/New_York"
      value = value.in_time_zone(tz).to_date
    end

    value
  end

  def extract_new_booking_lines old_hash, new_hash
    new_bl = json_child_entities(new_hash, "BookingLine")
    old_bl = json_child_entities(old_hash, "BookingLine")

    old_bl_ids = old_bl.map {|bl| json_entity_type_and_id(bl)[1] }

    new_booking_lines = []
    new_bl.each do |bl|
      *, id = json_entity_type_and_id(bl)
      new_booking_lines << bl unless old_bl_ids.include?(id)
    end

    new_booking_lines
  end

  def update_order_number_on_booking_lines booking_lines, changes, user, shipment_reference
    # The easiest way to determine which orders are connected to the shipment is through the booking.  
    # LL should never have shipment lines connected to an order that aren't also in the booking lines, so
    # this should work fine.
    order_numbers = booking_lines.map {|line| mf(line, :bkln_order_number)}.uniq.compact
    order_numbers.each do |order_number|
      order = Order.where(order_number: order_number).first
      if order
        Lock.db_lock(order) do 
          update_order(order, changes, user, shipment_reference)
        end
      end
    end
  end

  def update_order order, changes, user, shipment_reference
    update_order = false
    changes.each_pair do |k, v|
      existing_value = order.custom_value(cdefs[k])
      if existing_value != v
        order.find_and_set_custom_value(cdefs[k], v)
        update_order = true
      end
    end

    if update_order
      order.save!
      order.create_snapshot user, nil, "Shipment Updated Data Recorder - Shipment # #{shipment_reference}"
    end

    nil
  end

end; end; end; end