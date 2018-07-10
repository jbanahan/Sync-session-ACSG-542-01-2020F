require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberOrderSnapshotDiscrepancyReport
  include LumberCustomDefinitionSupport
  include OpenChain::Report::ReportHelper

  def initialize
    @cdefs = self.class.prep_custom_definitions [:ordln_po_create_article,:ordln_po_booked_article,
      :ordln_po_shipped_article,:ordln_po_create_quantity,:ordln_po_booked_quantity,:ordln_po_shipped_quantity,
      :ordln_po_create_hts,:ordln_po_booked_hts,:ordln_po_shipped_hts,:ord_snapshot_discrepancy_comment,
      :ordln_po_create_price_per_unit,:ordln_po_booked_price_per_unit,:ordln_po_shipped_price_per_unit,
      :ordln_po_create_total_price,:ordln_po_booked_total_price,:ordln_po_shipped_total_price,
      :ordln_po_create_country_origin,:ordln_po_booked_country_origin,:ordln_po_shipped_country_origin]
  end

  def self.permission? user
    MasterSetup.get.custom_feature?("Lumber Liquidators") && (user.view_orders? || user.view_shipments?)
  end

  def self.run_report user, settings = {}
    self.new.run settings['open_orders_only'], settings['snapshot_range_start_date'], settings['snapshot_range_end_date']
  end

  def run open_orders_only, snapshot_range_start, snapshot_range_end
    qry = query(open_orders_only, snapshot_range_start, snapshot_range_end)
    wb = generate_report qry, snapshot_range_start, snapshot_range_end
    workbook_to_tempfile wb, "LumberOrderSnapshotDiscrepancy"
  end

  private
    def generate_report query, snapshot_range_start, snapshot_range_end
      wb, sheet = XlsMaker.create_workbook_and_sheet "Discrepancies", ["PO", "Order Line", "Vendor", "PO Create Date", "Booking Requested Date", "Shipment Date", "Entry Date", "Goods Receipt Date", "Snapshot Date", "Snapshot Discrepancy Comments", "Field", "PO Creation", "Booking Requested", "Shipment", "Entry", "Goods Receipt"]

      # Unfortunately, the data has to be written off to a collection of objects before generating the Excel spreadsheet
      # because Lumber wants the rows sorted by snapshot date.  Snapshot date is a computed field that could (although
      # it probably won't) differ within items on the same PO, which are also supposed to be grouped together.
      row_grouping_hash = Hash.new

      result_set = ActiveRecord::Base.connection.exec_query query
      result_set.each do |row_hash|
        process_discrepancy 'Article', row_hash['article_created'], row_hash['article_booked'], row_hash['article_shipped'],
            row_hash['article_created_date'], row_hash['article_booked_date'], row_hash['article_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
        process_discrepancy 'Quantity', row_hash['quantity_created'], row_hash['quantity_booked'], row_hash['quantity_shipped'],
            row_hash['quantity_created_date'], row_hash['quantity_booked_date'], row_hash['quantity_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
        process_discrepancy 'HTS', row_hash['hts_created'], row_hash['hts_booked'], row_hash['hts_shipped'],
            row_hash['hts_created_date'], row_hash['hts_booked_date'], row_hash['hts_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
        process_discrepancy 'Price/Unit', row_hash['unit_price_created'], row_hash['unit_price_booked'], row_hash['unit_price_shipped'],
            row_hash['unit_price_created_date'], row_hash['unit_price_booked_date'], row_hash['unit_price_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
        process_discrepancy 'Total Price', row_hash['total_price_created'], row_hash['total_price_booked'], row_hash['total_price_shipped'],
            row_hash['total_price_created_date'], row_hash['total_price_booked_date'], row_hash['total_price_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
        process_discrepancy 'Country of Origin', row_hash['country_origin_created'], row_hash['country_origin_booked'], row_hash['country_origin_shipped'],
            row_hash['country_origin_created_date'], row_hash['country_origin_booked_date'], row_hash['country_origin_shipped_date'],
            row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
      end

      # Sort the values in the hash by 'overall' snapshot date per PO.  We still want to keep all the lines from a PO
      # combined together in the report that will be generated, but those blocks of PO lines should be sorted on snapshot date.
      row_grouping_arr = row_grouping_hash.values.sort_by { |v| v.snapshot_date }

      # Loop through the sorted row-groupings, generating report rows.  Each grouping will result in 1+ row...potentially
      # one row for every field being checked for discrepancy times the number of lines on the PO, though it should be
      # far less than this in practice, since most of the checked fields won't change between PO creation and shipping.
      # Per LL request, a blank line is added in between every block of rows specific to one PO.  They have been made
      # aware that this doesn't play well with sorting the spreadsheet results (blank lines will be sorted to beginning
      # or end of the document, depending on sort options).
      row_number = 0
      gray_format = XlsMaker.create_format "gray_row", pattern: 1, pattern_fg_color: :silver
      row_grouping_arr.each do |row_grouping|
        if row_number > 0
          # Spacer line between POs.
          row_number += 1
          XlsMaker.add_body_row sheet, row_number, ['', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']
          XlsMaker.set_cell_formats sheet, row_number, [gray_format, gray_format, gray_format, gray_format,
              gray_format, gray_format, gray_format, gray_format, gray_format, gray_format, gray_format, gray_format,
              gray_format, gray_format, gray_format, gray_format]
        end
        row_grouping.rows.each do |row|
          XlsMaker.add_body_row sheet, (row_number += 1), [
              XlsMaker.create_link_cell(row_grouping.order_link, row_grouping.order_number), row.order_line_number,
              row_grouping.vendor, row_grouping.po_create_date, row_grouping.booking_requested_date,
              row_grouping.shipment_date, '', '', row.snapshot_date, row_grouping.snapshot_discrepancy_comments,
              row.discrepancy_field, row.po_creation_value, row.booking_requested_value, row.shipment_value, '', ''
          ]
        end
      end

      XlsMaker.set_column_widths sheet, [20, 20, 25, 20, 23, 20, 20, 20, 20, 30, 20, 20, 20, 20, 20, 20]

      wb
    end

    def is_discrepancy val_1, val_2, date_1, date_2
      # The date nil checks are done to ensure that we're not treating absent records as nil values, which could
      # happen when dealing with orders that had not yet shipped, for example: we'd have a created snapshot, but
      # no shipped snapshot.  The date will only be nil if the snapshot custom value record doesn't exist.
      val_1 != val_2 && !date_1.nil? && !date_2.nil?
    end

    # Looks to see if the values in a particular field has actually changed between point of PO creation and when the
    # order ultimately shipped (i.e. "discrepancy").  If there has been no change, this method does nothing: this is not
    # something that needs to be on the report.  If a discrepancy is encountered, a row object is created.
    def process_discrepancy discrepancy_field, created_value, booked_value, shipped_value, created_snapshot_date, booked_snapshot_date, shipped_snapshot_date, row_hash, row_grouping_hash, snapshot_range_start, snapshot_range_end
    if (is_discrepancy(created_value, booked_value, created_snapshot_date, booked_snapshot_date) ||
          is_discrepancy(created_value, shipped_value, created_snapshot_date, shipped_snapshot_date) ||
          is_discrepancy(booked_value, shipped_value, booked_snapshot_date, shipped_snapshot_date))
        snapshot_date = shipped_snapshot_date
        if !snapshot_date
          snapshot_date = booked_snapshot_date
        end

        # The snapshot date for a line is actually a computed value, and isn't necessarily in lock step with the
        # query used to get this value.  The query can return, for example, a line where the booked snapshot
        # occurs within a date range while the shipped snapshot is outside it.  This date check prevents that
        # situation (which really isn't THAT bad, but might result in some customer questions).
        if (snapshot_range_start.blank? || snapshot_date >= DateTime.strptime(snapshot_range_start, '%Y-%m-%d')) &&
            (snapshot_range_end.blank? || snapshot_date < DateTime.strptime(snapshot_range_end, '%Y-%m-%d'))
          order_number = row_hash['order_number']
          row_grouping = row_grouping_hash[order_number]
          if !row_grouping
            row_grouping = LumberOrderSnapshotDiscrepancyRowGrouping.new
            row_grouping.order_number = order_number
            # Potential future performance enhancement: allow access to CoreObjectSupport's excel_url method without
            # having to load the Order object.  We have the order ID already, and there's not really anything else
            # needed from the PO for the link creation.
            row_grouping.order_link = Order.find(row_hash['order_id']).try(:excel_url)
            row_grouping.po_create_date = row_hash['po_create_date']
            row_grouping.booking_requested_date = row_hash['booking_received_date']
            row_grouping.shipment_date = row_hash['departure_date']
            row_grouping.snapshot_discrepancy_comments = row_hash['discrepancy_comments']
            row_grouping.vendor = row_hash['vendor_name']
            row_grouping.rows = []
            row_grouping_hash[order_number] = row_grouping
          end

          # Make sure the grouping has the earliest snapshot date across the PO.  This is mostly just a safety precaution
          # against there being variation in the dates.  Really, it should be minimal or none since all lines on the
          # PO will have been booked/shipped on the same shipment (LL doesn't split).  We are dealing with separate
          # 'updated_at' fields per custom definition, however, so there could be some variance.
          if !row_grouping.snapshot_date || snapshot_date < row_grouping.snapshot_date
            row_grouping.snapshot_date = snapshot_date
          end

          row = LumberOrderSnapshotDiscrepancyRow.new
          row.order_line_number = row_hash['line_number']
          row.discrepancy_field = discrepancy_field
          row.snapshot_date = snapshot_date
          row.po_creation_value = created_value
          row.booking_requested_value = booked_value
          row.shipment_value = shipped_value
          row_grouping.rows << row
        end
      end
    end

    class LumberOrderSnapshotDiscrepancyRowGrouping
      attr_accessor :order_link, :order_number, :po_create_date, :vendor, :po_create_date, :booking_requested_date,
                    :shipment_date, :snapshot_date, :snapshot_discrepancy_comments, :rows
    end

    class LumberOrderSnapshotDiscrepancyRow
      attr_accessor :order_line_number, :snapshot_date, :discrepancy_field, :po_creation_value, :booking_requested_value,
                    :shipment_value
    end

    def query open_orders_only, snapshot_range_start, snapshot_range_end
      <<-QRY
        SELECT 
          ord.id AS order_id, 
          ord.order_number, 
          ol.line_number, 
          vendor.name AS vendor_name, 
          ord.created_at AS po_create_date, 
          shp.booking_received_date, 
          shp.departure_date, 
          cv_discrepancy_comments.text_value AS discrepancy_comments, 
          cv_article_created.string_value AS article_created, 
          cv_article_created.updated_at AS article_created_date, 
          cv_article_booked.string_value AS article_booked, 
          cv_article_booked.updated_at AS article_booked_date, 
          cv_article_shipped.string_value AS article_shipped,
          cv_article_shipped.updated_at AS article_shipped_date,
          cv_quantity_created.decimal_value AS quantity_created, 
          cv_quantity_created.updated_at AS quantity_created_date, 
          cv_quantity_booked.decimal_value AS quantity_booked, 
          cv_quantity_booked.updated_at AS quantity_booked_date, 
          cv_quantity_shipped.decimal_value AS quantity_shipped,
          cv_quantity_shipped.updated_at AS quantity_shipped_date,
          cv_hts_created.string_value AS hts_created, 
          cv_hts_created.updated_at AS hts_created_date, 
          cv_hts_booked.string_value AS hts_booked, 
          cv_hts_booked.updated_at AS hts_booked_date, 
          cv_hts_shipped.string_value AS hts_shipped,
          cv_hts_shipped.updated_at AS hts_shipped_date,
          cv_unit_price_created.decimal_value AS unit_price_created, 
          cv_unit_price_created.updated_at AS unit_price_created_date, 
          cv_unit_price_booked.decimal_value AS unit_price_booked, 
          cv_unit_price_booked.updated_at AS unit_price_booked_date, 
          cv_unit_price_shipped.decimal_value AS unit_price_shipped, 
          cv_unit_price_shipped.updated_at AS unit_price_shipped_date, 
          cv_total_price_created.decimal_value AS total_price_created, 
          cv_total_price_created.updated_at AS total_price_created_date, 
          cv_total_price_booked.decimal_value AS total_price_booked, 
          cv_total_price_booked.updated_at AS total_price_booked_date, 
          cv_total_price_shipped.decimal_value AS total_price_shipped, 
          cv_total_price_shipped.updated_at AS total_price_shipped_date, 
          cv_country_origin_created.string_value AS country_origin_created, 
          cv_country_origin_created.updated_at AS country_origin_created_date, 
          cv_country_origin_booked.string_value AS country_origin_booked, 
          cv_country_origin_booked.updated_at AS country_origin_booked_date, 
          cv_country_origin_shipped.string_value AS country_origin_shipped, 
          cv_country_origin_shipped.updated_at AS country_origin_shipped_date 
        FROM 
          orders AS ord 
          INNER JOIN order_lines as ol ON 
            ord.id = ol.order_id 
          LEFT OUTER JOIN booking_lines AS bl ON 
            ol.id = bl.order_line_id 
          LEFT OUTER JOIN shipments AS shp ON 
            bl.shipment_id = shp.id 
          LEFT OUTER JOIN custom_values AS cv_article_created ON 
            ol.id = cv_article_created.customizable_id AND 
            cv_article_created.customizable_type = 'OrderLine' AND 
            cv_article_created.custom_definition_id = #{@cdefs[:ordln_po_create_article].id}
          LEFT OUTER JOIN custom_values AS cv_article_booked ON 
            ol.id = cv_article_booked.customizable_id AND 
            cv_article_booked.customizable_type = 'OrderLine' AND 
            cv_article_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_article].id}
          LEFT OUTER JOIN custom_values AS cv_article_shipped ON 
            ol.id = cv_article_shipped.customizable_id AND 
            cv_article_shipped.customizable_type = 'OrderLine' AND 
            cv_article_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_article].id}
          LEFT OUTER JOIN custom_values AS cv_quantity_created ON 
            ol.id = cv_quantity_created.customizable_id AND 
            cv_quantity_created.customizable_type = 'OrderLine' AND 
            cv_quantity_created.custom_definition_id = #{@cdefs[:ordln_po_create_quantity].id}
          LEFT OUTER JOIN custom_values AS cv_quantity_booked ON 
            ol.id = cv_quantity_booked.customizable_id AND 
            cv_quantity_booked.customizable_type = 'OrderLine' AND 
            cv_quantity_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_quantity].id}
          LEFT OUTER JOIN custom_values AS cv_quantity_shipped ON 
            ol.id = cv_quantity_shipped.customizable_id AND 
            cv_quantity_shipped.customizable_type = 'OrderLine' AND 
            cv_quantity_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_quantity].id}
          LEFT OUTER JOIN custom_values AS cv_hts_created ON 
            ol.id = cv_hts_created.customizable_id AND 
            cv_hts_created.customizable_type = 'OrderLine' AND 
            cv_hts_created.custom_definition_id = #{@cdefs[:ordln_po_create_hts].id}
          LEFT OUTER JOIN custom_values AS cv_hts_booked ON 
            ol.id = cv_hts_booked.customizable_id AND 
            cv_hts_booked.customizable_type = 'OrderLine' AND 
            cv_hts_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_hts].id}
          LEFT OUTER JOIN custom_values AS cv_hts_shipped ON 
            ol.id = cv_hts_shipped.customizable_id AND 
            cv_hts_shipped.customizable_type = 'OrderLine' AND 
            cv_hts_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_hts].id}
          LEFT OUTER JOIN custom_values AS cv_unit_price_created ON 
            ol.id = cv_unit_price_created.customizable_id AND 
            cv_unit_price_created.customizable_type = 'OrderLine' AND 
            cv_unit_price_created.custom_definition_id = #{@cdefs[:ordln_po_create_price_per_unit].id}
          LEFT OUTER JOIN custom_values AS cv_unit_price_booked ON 
            ol.id = cv_unit_price_booked.customizable_id AND 
            cv_unit_price_booked.customizable_type = 'OrderLine' AND 
            cv_unit_price_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_price_per_unit].id}
          LEFT OUTER JOIN custom_values AS cv_unit_price_shipped ON 
            ol.id = cv_unit_price_shipped.customizable_id AND 
            cv_unit_price_shipped.customizable_type = 'OrderLine' AND 
            cv_unit_price_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_price_per_unit].id}
          LEFT OUTER JOIN custom_values AS cv_total_price_created ON 
            ol.id = cv_total_price_created.customizable_id AND 
            cv_total_price_created.customizable_type = 'OrderLine' AND 
            cv_total_price_created.custom_definition_id = #{@cdefs[:ordln_po_create_total_price].id}
          LEFT OUTER JOIN custom_values AS cv_total_price_booked ON 
            ol.id = cv_total_price_booked.customizable_id AND 
            cv_total_price_booked.customizable_type = 'OrderLine' AND 
            cv_total_price_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_total_price].id}
          LEFT OUTER JOIN custom_values AS cv_total_price_shipped ON 
            ol.id = cv_total_price_shipped.customizable_id AND 
            cv_total_price_shipped.customizable_type = 'OrderLine' AND 
            cv_total_price_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_total_price].id}
          LEFT OUTER JOIN custom_values AS cv_country_origin_created ON 
            ol.id = cv_country_origin_created.customizable_id AND 
            cv_country_origin_created.customizable_type = 'OrderLine' AND 
            cv_country_origin_created.custom_definition_id = #{@cdefs[:ordln_po_create_country_origin].id}
          LEFT OUTER JOIN custom_values AS cv_country_origin_booked ON 
            ol.id = cv_country_origin_booked.customizable_id AND 
            cv_country_origin_booked.customizable_type = 'OrderLine' AND 
            cv_country_origin_booked.custom_definition_id = #{@cdefs[:ordln_po_booked_country_origin].id}
          LEFT OUTER JOIN custom_values AS cv_country_origin_shipped ON 
            ol.id = cv_country_origin_shipped.customizable_id AND 
            cv_country_origin_shipped.customizable_type = 'OrderLine' AND 
            cv_country_origin_shipped.custom_definition_id = #{@cdefs[:ordln_po_shipped_country_origin].id}
          LEFT OUTER JOIN custom_values AS cv_discrepancy_comments ON 
            ord.id = cv_discrepancy_comments.customizable_id AND 
            cv_discrepancy_comments.customizable_type = 'Order' AND 
            cv_discrepancy_comments.custom_definition_id = #{@cdefs[:ord_snapshot_discrepancy_comment].id} 
          LEFT OUTER JOIN companies AS vendor ON 
            ord.vendor_id = vendor.id
        WHERE 
          #{open_orders_only ? "ord.closed_at IS NULL AND " : ""}
          (
            (
              cv_article_created.id IS NOT NULL AND 
              cv_article_booked.id IS NOT NULL AND 
              !(cv_article_created.string_value <=> cv_article_booked.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_article_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_article_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_article_created.id IS NOT NULL AND 
              cv_article_shipped.id IS NOT NULL AND 
              !(cv_article_created.string_value <=> cv_article_shipped.string_value)  
              #{has_value(snapshot_range_start) ? (" AND cv_article_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_article_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_article_booked.id IS NOT NULL AND 
              cv_article_shipped.id IS NOT NULL AND 
              !(cv_article_booked.string_value <=> cv_article_shipped.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_article_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_article_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_quantity_created.id IS NOT NULL AND 
              cv_quantity_booked.id IS NOT NULL AND 
              !(cv_quantity_created.decimal_value <=> cv_quantity_booked.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_quantity_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_quantity_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_quantity_created.id IS NOT NULL AND 
              cv_quantity_shipped.id IS NOT NULL AND 
              !(cv_quantity_created.decimal_value <=> cv_quantity_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_quantity_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_quantity_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_quantity_booked.id IS NOT NULL AND 
              cv_quantity_shipped.id IS NOT NULL AND 
              !(cv_quantity_booked.decimal_value <=> cv_quantity_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_quantity_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_quantity_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_hts_created.id IS NOT NULL AND 
              cv_hts_booked.id IS NOT NULL AND 
              !(cv_hts_created.string_value <=> cv_hts_booked.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_hts_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_hts_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_hts_created.id IS NOT NULL AND 
              cv_hts_shipped.id IS NOT NULL AND 
              !(cv_hts_created.string_value <=> cv_hts_shipped.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_hts_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_hts_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_hts_booked.id IS NOT NULL AND 
              cv_hts_shipped.id IS NOT NULL AND 
              !(cv_hts_booked.string_value <=> cv_hts_shipped.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_hts_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_hts_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_unit_price_created.id IS NOT NULL AND 
              cv_unit_price_booked.id IS NOT NULL AND 
              !(cv_unit_price_created.decimal_value <=> cv_unit_price_booked.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_unit_price_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_unit_price_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_unit_price_created.id IS NOT NULL AND 
              cv_unit_price_shipped.id IS NOT NULL AND 
              !(cv_unit_price_created.decimal_value <=> cv_unit_price_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_unit_price_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_unit_price_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_unit_price_booked.id IS NOT NULL AND 
              cv_unit_price_shipped.id IS NOT NULL AND 
              !(cv_unit_price_booked.decimal_value <=> cv_unit_price_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_unit_price_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_unit_price_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_total_price_created.id IS NOT NULL AND 
              cv_total_price_booked.id IS NOT NULL AND 
              !(cv_total_price_created.decimal_value <=> cv_total_price_booked.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_total_price_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_total_price_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_total_price_created.id IS NOT NULL AND 
              cv_total_price_shipped.id IS NOT NULL AND 
              !(cv_total_price_created.decimal_value <=> cv_total_price_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_total_price_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_total_price_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_total_price_booked.id IS NOT NULL AND 
              cv_total_price_shipped.id IS NOT NULL AND 
              !(cv_total_price_booked.decimal_value <=> cv_total_price_shipped.decimal_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_total_price_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_total_price_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_country_origin_created.id IS NOT NULL AND 
              cv_country_origin_booked.id IS NOT NULL AND 
              !(cv_country_origin_created.string_value <=> cv_country_origin_booked.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_country_origin_booked.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_country_origin_booked.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_country_origin_created.id IS NOT NULL AND 
              cv_country_origin_shipped.id IS NOT NULL AND 
              !(cv_country_origin_created.string_value <=> cv_country_origin_shipped.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_country_origin_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_country_origin_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) OR 
            (
              cv_country_origin_booked.id IS NOT NULL AND 
              cv_country_origin_shipped.id IS NOT NULL AND 
              !(cv_country_origin_booked.string_value <=> cv_country_origin_shipped.string_value) 
              #{has_value(snapshot_range_start) ? (" AND cv_country_origin_shipped.updated_at >= '" + snapshot_range_start + "'") : ""}
              #{has_value(snapshot_range_end) ? (" AND cv_country_origin_shipped.updated_at < '" + snapshot_range_end + "'") : ""} 
            ) 
          )
        ORDER BY 
          ord.order_number, 
          ol.line_number
      QRY
    end

    def has_value v
      !v.to_s.strip.empty?
    end

end; end; end; end;