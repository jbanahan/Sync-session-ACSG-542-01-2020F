require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'
require 'open_chain/custom_handler/pvh/pvh_fiscal_calendar_scheduling_support'
require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module Report; class PvhCanadaDutyDiscountReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
  include OpenChain::CustomHandler::Pvh::PvhFiscalCalendarSchedulingSupport
  extend OpenChain::FiscalCalendarSchedulingSupport

  PvhReportData ||= Struct.new(:entry_number, :invoice_number, :po_number, :shipment_number, :po_line_number,
                               :release_date, :eta_date, :currency, :exchange_rate, :vendor_invoice_value,
                               :entered_value, :duty_deductions, :duty_assist_amount, :dutiable_value,
                               :duty_rate_pct, :first_cost, :units_shipped, :hts_code, :mode_of_transport,
                               :total_duty_savings, :total_duty_difference, :total_dutiable_value, :rows) do
    def initialize
      self.vendor_invoice_value ||= 0.0
      self.duty_deductions ||= 0.0
      self.duty_assist_amount ||= 0.0
      self.total_dutiable_value ||= 0.0
      self.total_duty_savings ||= 0.0
      self.total_duty_difference ||= 0.0
      self.rows ||= []
    end

    def duty_savings
      # Duty savings is only to be calculated if the duty deduction is no more than a quarter of the vendor
      # invoice value.  If that's not the case, savings is deemed to be zero.  (This decree came from PVH.
      # The "why" is unclear, but probably ties into some customs regulation.)
      if self.vendor_invoice_value * BigDecimal(".25") >= self.duty_deductions.abs
        # PVH wants this to be displayed as a positive number.
        (self.duty_deductions.abs * (self.duty_rate_pct / BigDecimal(100))).round(2).abs
      else
        BigDecimal(0)
      end
    end

    def dutiable_value
      # Duty deductions is a negative number.
      self.vendor_invoice_value + self.duty_assist_amount + self.duty_deductions
    end

    def duty_difference
      # We're just duping the Duty Deductions field in this field, then making the negative value positive.
      # Has to do with PVH not wanting to update macros.
      self.duty_deductions.abs
    end
  end

  def self.permission? user
    OpenChain::Report::PvhDutyDiscountReport.permission? user
  end

  def self.run_report _run_by, settings
    self.new.run_duty_discount_report settings
  end

  def self.run_schedulable settings = {}
    raise "Email address is required." if settings['email'].blank?
    run_if_configured(settings) do |fiscal_month, _fiscal_date|
      self.new.run_duty_discount_report settings, current_fiscal_month: fiscal_month
    end
  end

  def run_duty_discount_report settings, current_fiscal_month: nil
    scheduling_type = self.class.scheduling_type settings
    fiscal_date_start, fiscal_date_end, fiscal_month, fiscal_year = get_fiscal_period_dates settings['fiscal_month'], current_fiscal_month, scheduling_type, "PVHCANADA"

    workbook = nil
    distribute_reads do
      workbook = generate_report fiscal_date_start, fiscal_date_end
    end

    fiscal_descriptor = filename_fiscal_descriptor(fiscal_year, fiscal_month, scheduling_type)
    file_name = "PVHCANADA_Duty_Discount_#{fiscal_descriptor}_#{ActiveSupport::TimeZone[time_zone].now.strftime("%Y-%m-%d")}.xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "PVH Duty Discount", file_name: file_name do |temp|
        body_msg = "Attached is the \"Duty Discount Report, #{fiscal_year}-#{fiscal_month}\" based on CADEX Acceptance Date."
        OpenMailer.send_simple_html(settings['email'], "PVH Canada Duty Discount Report", body_msg, temp).deliver_now
      end
    else
      workbook_to_tempfile(workbook, "PVH Canada Duty Discount Savings", file_name: file_name.to_s)
    end
  end

  private

    def generate_report fiscal_date_start, fiscal_date_end
      wb = XlsxBuilder.new
      assign_styles wb

      result_set = ActiveRecord::Base.connection.exec_query make_query(fiscal_date_start, fiscal_date_end)
      shipments_hash = {}

      raw_data = []
      result_set.each do |result_set_row|
        # This look-up must be done at invoice line level, not HTS (hence why HTS is not joined into the query).
        # The process prevents the same shipment line from being returned twice, which means that multi-tariff
        # lines would not have a PO line number for their second report line.  It's also inefficient to look for
        # the shipment/order line multiple times per commercial invoice line.
        po_line_number, container_number = get_po_line_values result_set_row, shipments_hash

        d = PvhReportData.new
        d.entry_number = result_set_row['entry_number']
        d.invoice_number = result_set_row['invoice_number']
        d.po_number = result_set_row['po_number']

        # The value for the "Shipment Number" field varies by mode of transportation.
        ship_mode = result_set_row['transport_mode_code']
        if Entry.get_transport_mode_codes_us_ca("Sea").include?(ship_mode.to_i)
          d.shipment_number = container_number
        else
          d.shipment_number = result_set_row['master_bills_of_lading']
        end

        d.po_line_number = po_line_number
        d.release_date = result_set_row['release_date']
        # Falls back to arrival date if there is no ETA date.
        d.eta_date = result_set_row['eta_date'] || result_set_row['arrival_date']
        d.currency = result_set_row['currency']
        d.exchange_rate = result_set_row['exchange_rate']
        d.vendor_invoice_value = (result_set_row['value'] || BigDecimal(0)).round(2)
        d.entered_value = (result_set_row['entered_value'] || BigDecimal(0)).round(2)
        d.duty_deductions = (result_set_row['miscellaneous_discount'] || BigDecimal(0)).round(2)
        if d.duty_deductions > 0
          # These values should always be positive in the database, but PVH wants them displayed as negative.
          d.duty_deductions = -d.duty_deductions
        end
        d.duty_assist_amount = (result_set_row['add_to_make_amount'] || BigDecimal(0)).round(2)
        d.duty_rate_pct = ((result_set_row['duty_rate'] || BigDecimal(0)) * BigDecimal(100)).round(2)
        d.first_cost = (result_set_row['unit_price'] || BigDecimal(0)).round(2)
        d.units_shipped = result_set_row['quantity']
        d.hts_code = result_set_row['hts_code']
        d.mode_of_transport = result_set_row['transport_mode_code']
        raw_data << d
      end

      entry_hash = summarize_by_entry_number raw_data
      generate_detail_sheet wb, entry_hash
      generate_summary_sheet wb, entry_hash

      wb
    end

    def get_po_line_values result_set_row, shipments_hash
      # Involving a hash because there could be many lines per entry, and the shipments look-up is entry-level.
      transport_mode_code = result_set_row['transport_mode_code']
      master_bills = result_set_row['master_bills_of_lading']
      house_bills = result_set_row['house_bills_of_lading']
      key = [transport_mode_code, master_bills, house_bills]
      if shipments_hash.key? key
        shipments = shipments_hash[key]
      else
        shipments = find_shipments(transport_mode_code, Entry.split_newline_values(master_bills), Entry.split_newline_values(house_bills), force_lookup: true)
        shipments_hash[key] = shipments
      end

      # Invoice number is used only for ocean LCL entries.
      invoice_number = ocean_lcl_entry?(transport_mode_code, result_set_row['fcl_lcl']) ? result_set_row['invoice_number'] : nil
      shipment_line = find_shipment_line(shipments, nil, result_set_row['po_number'], result_set_row['part_number'],
                                         result_set_row['quantity'], invoice_number: invoice_number)

      order_line = shipment_line&.order_line
      po_line_number = order_line&.line_number
      container_number = shipment_line&.container&.container_number
      [po_line_number, container_number]
    end

    # Condenses the rows in the array together by entry number, returning them as a hash (containing sub-arrays).
    def summarize_by_entry_number data_arr
      entry_hash = {}
      data_arr.each do |row|
        entry_data = entry_hash[row.entry_number]
        if entry_data.nil?
          entry_data = PvhReportData.new
          entry_hash[row.entry_number] = entry_data

          # This data should be consistent through all rows related to the same entry.
          entry_data.entry_number = row.entry_number
          entry_data.eta_date = row.eta_date
          entry_data.mode_of_transport = row.mode_of_transport
        end
        entry_data.vendor_invoice_value += row.vendor_invoice_value
        entry_data.duty_deductions += row.duty_deductions
        entry_data.duty_assist_amount += row.duty_assist_amount
        entry_data.total_dutiable_value += row.dutiable_value
        entry_data.total_duty_savings += row.duty_savings
        entry_data.total_duty_difference += row.duty_difference
        entry_data.rows << row
      end
      entry_hash
    end

    # There is no need to condense the overall data on this tab.
    def generate_detail_sheet wb, entry_hash
      sheet = wb.create_sheet "Detail", headers: ["Entry Number", "Invoice Number", "PO Number",
                                                  "Shipment Number", "PO Line", "HTS Code", "Release Date", "ETA",
                                                  "Currency Type", "Exchange Rate", "Vendor Invoice Value (USD)",
                                                  "Tariff Entered Value (CAD)", "Duty Assist Amount (USD)",
                                                  "Duty Deductions (USD)", "Dutiable Value (USD)",
                                                  "Duty Savings (USD)", "Duty Rate PCT", "First Cost (USD)",
                                                  "Units Shipped", "Mode of Transport"]

      entry_hash.each_key do |entry_number|
        summary_row = entry_hash[entry_number]
        styles = [nil, nil, nil, nil, nil, nil, :date, :date, nil, :decimal_4_digits, :decimal, :decimal, :decimal,
                  :decimal, :decimal, :decimal, :decimal, :decimal, :integer, nil]
        summary_row.rows.each do |row|
          values = [row.entry_number, row.invoice_number, row.po_number, row.shipment_number, row.po_line_number,
                    row.hts_code, row.release_date, row.eta_date, row.currency, row.exchange_rate,
                    row.vendor_invoice_value, row.entered_value, row.duty_assist_amount, row.duty_deductions,
                    row.dutiable_value, row.duty_savings, row.duty_rate_pct, row.first_cost, row.units_shipped,
                    convert_transport_mode(row.mode_of_transport)]
          wb.add_body_row sheet, values, styles: styles
        end
      end

      wb.set_column_widths sheet, *Array.new(19, 20)

      sheet
    end

    def generate_summary_sheet wb, entry_hash
      sheet = wb.create_sheet "Summary", headers: ["Entry Number", "ETA", "Vendor Invoice Value (USD)",
                                                   "Duty Assist Amount (USD)", "Duty Deductions (USD)",
                                                   "Dutiable Value (USD)", "Duty Difference (USD)",
                                                   "Duty Savings (USD)", "Mode of Transport"]

      entry_hash.each_value do |row|
        values = [row.entry_number, row.eta_date, row.vendor_invoice_value, row.duty_assist_amount, row.duty_deductions,
                  row.total_dutiable_value, row.total_duty_difference, row.total_duty_savings, convert_transport_mode(row.mode_of_transport)]
        styles = [nil, :date, :decimal, :decimal, :decimal, :decimal, :decimal, :decimal, nil]
        wb.add_body_row sheet, values, styles: styles
      end

      # Totals row
      values = ["Grand Totals", nil, make_sum_formula("C", entry_hash.size), make_sum_formula("D", entry_hash.size), make_sum_formula("E", entry_hash.size),
                make_sum_formula("F", entry_hash.size), make_sum_formula("G", entry_hash.size), make_sum_formula("H", entry_hash.size), nil]
      styles = [:bold, nil, :decimal, :decimal, :decimal, :decimal, :decimal, :decimal, nil]
      wb.add_body_row sheet, values, styles: styles

      # Entry count rows.
      styles = [:bold, :integer]
      wb.add_body_row sheet, ["Total Entries (SEA)", make_entry_count_formula("SEA", entry_hash.size)], styles: styles
      wb.add_body_row sheet, ["Total Entries (AIR)", make_entry_count_formula("AIR", entry_hash.size)], styles: styles

      wb.set_column_widths sheet, *Array.new(9, 20)

      sheet
    end

    def make_sum_formula column, entry_count
      entry_count > 0 ? "=SUBTOTAL(9, #{column}2:#{column}#{entry_count + 1})" : BigDecimal("0")
    end

    def make_entry_count_formula transport_mode, entry_count
      entry_count > 0 ? "=COUNTIF(I2:I#{entry_count + 1}, \"#{transport_mode}\")" : 0
    end

    def assign_styles wb
      wb.create_style :bold, {b: true}
      wb.create_style :decimal, {format_code: "#,##0.00"}
      wb.create_style :decimal_4_digits, {format_code: "#,##0.0000"}
      wb.create_style :integer, {format_code: "#,##0"}
      wb.create_style :bold_decimal, {format_code: "#,##0.00", b: true}
      wb.create_style :date, {format_code: "MM/DD/YYYY"}
    end

    def convert_transport_mode value
      @transport_mode_lambda ||= transport_mode_us_ca_translation_lambda
      @transport_mode_lambda.call(nil, value)
    end

    def make_query fiscal_date_start, fiscal_date_end
      <<-SQL
          SELECT
            ent.entry_number,
            ci.invoice_number,
            cil.po_number,
            ent.release_date,
            ent.eta_date,
            ent.arrival_date,
            ci.currency,
            ci.exchange_rate,
            cil.value,
            cil.miscellaneous_discount,
            cil.add_to_make_amount,
            cil.adjustments_amount,
            cil.unit_price,
            cil.quantity,
            cil.part_number,
            cil.id AS commercial_invoice_line_id,
            ent.transport_mode_code,
            ent.master_bills_of_lading,
            ent.house_bills_of_lading,
            ent.fcl_lcl,
            tar.hts_code,
            tar.entered_value,
            tar.duty_rate
          FROM
            entries AS ent
            LEFT OUTER JOIN commercial_invoices AS ci ON
              ent.id = ci.entry_id
            LEFT OUTER JOIN commercial_invoice_lines AS cil ON
              ci.id = cil.commercial_invoice_id
            LEFT OUTER JOIN commercial_invoice_tariffs AS tar ON
              cil.id = tar.commercial_invoice_line_id
          WHERE
            ent.customer_number = 'PVHCANADA' AND
            ent.fiscal_date >= '#{fiscal_date_start}' AND
            ent.fiscal_date <= '#{fiscal_date_end}' AND
            cil.miscellaneous_discount IS NOT NULL AND
            cil.miscellaneous_discount > 0
          ORDER BY
            ent.entry_number,
            ci.invoice_number,
            cil.po_number
      SQL
    end

end; end; end