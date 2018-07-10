require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'

# Extracts the data from the snapshot that LL wants to store off as "milestone snapshot" data, as a point
# in time reference to what these values were when the order was first created.
#
# We're actually going to refer to "created" as when the line itself was created, not when the order was.
# Otherwise, if any lines get added later they will not get this data recorded.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderCreatedDataRecorder
  include OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionSupport
  include OpenChain::EntityCompare::ComparatorHelper

  def record_data order, old_snapshot, new_snapshot
    # Essentially what we're looking for here is lines (by line number) that did not exist on the old snapshot but appear on the new.
    created_lines = extract_created_lines(old_snapshot, new_snapshot)
    order_updated = false

    created_lines.each do |line|
      updated = record_order_line_data(order, new_snapshot, line)
      order_updated = true if updated == true
    end

    order_updated
  end

  private 
    def extract_created_lines old_snapshot, new_snapshot
      old_lines = json_child_entities(old_snapshot, "OrderLine")
      new_lines = json_child_entities(new_snapshot, "OrderLine")

      old_line_numbers = Set.new(old_lines.map {|l| mf(l, :ordln_line_number) })

      created_lines = []
      new_lines.each do |new_line|
        created_lines << new_line unless old_line_numbers.include?(mf(new_line, :ordln_line_number))
      end

      created_lines
    end

    def record_order_line_data order, snapshot, line_snapshot
      line_number = mf(line_snapshot, :ordln_line_number)
      order_line = order.order_lines.find {|l| l.line_number == line_number}

      # This is potentially possible if we're processing snapshots that were taken a while ago, like if the queue is backed up,
      # and the order was since updated and the line deleted.  It's fine to ignore it.
      if order_line
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_article], mf(line_snapshot, :ordln_puid))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_quantity], mf(line_snapshot, :ordln_ordered_qty))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_hts], product_hts(line_snapshot))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_price_per_unit], mf(line_snapshot, :ordln_ppu))
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_total_price], mf(line_snapshot, :ordln_total_cost))
        # Country of Origin comes from the Order Header for LL
        order_line.find_and_set_custom_value(cdefs[:ordln_po_create_country_origin], mf(snapshot, cdefs[:ord_country_of_origin]))

        order_line.save!
        return true
      else
        return false
      end
    end

    def product_hts line_snapshot
      product = Product.where(unique_identifier: mf(line_snapshot, :ordln_puid)).first
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
        :ordln_po_create_article, :ordln_po_create_quantity, :ordln_po_create_hts, 
        :ordln_po_create_price_per_unit, :ordln_po_create_total_price, :ordln_po_create_country_origin]
    end

end; end; end; end