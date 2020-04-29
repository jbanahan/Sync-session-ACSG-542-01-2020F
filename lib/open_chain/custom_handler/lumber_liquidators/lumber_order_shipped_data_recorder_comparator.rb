require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/entity_compare/uncancelled_shipment_comparator'

# Extracts the data from the snapshot that LL wants to store off as "milestone snapshot" data, as a point
# in time reference to what these values were when the order was booked (if the order is re-booked, the
# the values will get updated).
#
# We're actually going to refer to "created" as when the line itself was booked.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderShippedDataRecorderComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    # The last exported from source field is set by the GT Nexus ASN Parser.  LL wants this data to be recorded when
    # the first ASN for the shipment is sent back from GTN, this is how we're tracking that.
    super(snapshot) && !snapshot.recordable.try(:last_exported_from_source).nil?
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    c = self.new
    c.record_data c.get_json_hash(old_bucket, old_path, old_version), c.get_json_hash(new_bucket, new_path, new_version)
  end

  # these are shipment snapshots (as we're tracking when booking lines are added to shipments here)
  def record_data old_snapshot, new_snapshot
    return unless asn_updated?(old_snapshot, new_snapshot)

    # Shipment Lines are not added by the ASN, so we'll just set the recorded data for any order line
    # linked to shipment lines referenced in the snapshot

    # The easiest way to do this is to just look up the order lines based on the ShipmentLine record ids
    # and then record each OrderLine individually if they haven't already been recorded
    # (then snapshot the updated orders at the end of the process).  We'll receive ASNs multiple times,
    # so we only want to record the order data the first time we receive ASN data referencing it.
    order_data = order_links(new_snapshot)

    master_bill = mf(new_snapshot, :shp_master_bill_of_lading)

    shipment_reference = mf(new_snapshot, :shp_ref)

    # Now that we have a listing of every order on the shipment and the lines for each one, we can
    # lock them and update each line that requires it and record the shipping data for the lines.
    user = User.integration
    order_data.each_pair do |order_id, lines|
      order = Order.where(id: order_id).first
      next unless order

      updated = false
      Lock.db_lock(order) do
        lines.each do |line_data|

          line = order.order_lines.find {|l| l.id == line_data[:line_id] }
          if line
            if record_order_line_data(order, line, master_bill, line_data[:container])
              updated = true
            end
          end

          order.create_snapshot(user, nil, "PO Shipped Data Recorder - Shipment # #{shipment_reference}") if updated
        end
      end
    end

  end

  private

    def order_links new_snapshot
      containers = {}
      json_child_entities(new_snapshot, "Container").each do |c|
        containers[mf(c, :con_container_number)] = c
      end

      order_data = {}
      json_child_entities(new_snapshot, "ShipmentLine").each do |line|
        order_line = OrderLine.joins(:piece_sets).where(piece_sets: {shipment_line_id: line["record_id"]}).first
        if order_line
          order_data[order_line.order_id] ||= []
          order_data[order_line.order_id] << {line_id: order_line.id, container: containers[mf(line, :shpln_container_number)]}
        end
      end

      order_data
    end

    def asn_updated? old_snapshot, new_snapshot
      old_exported = mf(old_snapshot, :shp_last_exported_from_source)
      new_exported = mf(new_snapshot, :shp_last_exported_from_source)

      old_exported.to_i != new_exported.to_i
    end

    def record_order_line_data order, order_line, bol_number, container_data
      # Don't update any line that already has the po_shipped data (use a field that should never be nil)
      # It's possible the ASN was sent multiple times, so don't update anything we've previously set data for.
      if order_line.custom_value(cdefs[:ordln_po_shipped_quantity]).nil?
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_article], order_line.product.try(:unique_identifier))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_quantity], order_line.quantity)
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_hts], product_hts(order_line))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_price_per_unit], order_line.price_per_unit)
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_total_price], order_line.total_cost)
        # Country of Origin comes from the Order Header for LL
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_country_origin], order.custom_value(cdefs[:ord_country_of_origin]))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_bol], bol_number)
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_container_number], mf(container_data, :con_container_number))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_shipped_seal_number], mf(container_data, :con_seal_number))

        order_line.save!
        return true
      else
        return false
      end
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
        :ordln_po_shipped_article, :ordln_po_shipped_quantity, :ordln_po_shipped_hts,
        :ordln_po_shipped_price_per_unit, :ordln_po_shipped_total_price, :ordln_po_shipped_country_origin,
        :ordln_po_shipped_bol, :ordln_po_shipped_container_number, :ordln_po_shipped_seal_number]
    end

end; end; end; end;