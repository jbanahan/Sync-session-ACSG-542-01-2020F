require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'
require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module Report; class PvhDutyDiscountReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
  extend OpenChain::FiscalCalendarSchedulingSupport

  PVH_DUTY_DISCOUNT_REPORT_USERS ||= 'pvh_duty_discount_report'
  
  PvhReportData ||= Struct.new(:entry_number, :invoice_number, :po_number, :shipment_number, :po_line_number,
                               :hts_code, :eta_date, :vendor_invoice_value, :duty_assist_amount, :dutiable_value,
                               :dutiable_value_7501, :duty_rate_pct, :first_cost_po, :units_shipped, :total_duty_adj_amount,
                               :total_duty_savings, :total_duty_difference, :rows, :base_duty_adj_amount, :transport_mode) do
    def initialize
      self.vendor_invoice_value ||= 0.0
      self.duty_assist_amount ||= 0.0
      # used for calculations
      self.dutiable_value ||= 0.0
      # used for display
      self.dutiable_value_7501 ||= 0.0
      self.total_duty_adj_amount ||= 0.0
      self.total_duty_savings ||= 0.0
      self.total_duty_difference ||= 0.0
      self.rows ||= []
    end

    def duty_adj_amount
      self.dutiable_value - self.vendor_invoice_value - self.duty_assist_amount
    end

    def duty_savings
      adj_amount = self.base_duty_adj_amount ? self.base_duty_adj_amount : self.duty_adj_amount
      (adj_amount.abs * (self.duty_rate_pct / BigDecimal.new(100))).round(2)
    end

    def duty_difference
      self.vendor_invoice_value - self.dutiable_value + self.duty_assist_amount
    end
  end

  def self.permission? user
    user.view_entries? && MasterSetup.get.custom_feature?("PVH Duty Discount Report") && user.in_group?(Group.use_system_group(PVH_DUTY_DISCOUNT_REPORT_USERS, name:"PVH Duty Discount Report", description:"Users able to run the PVH Duty Discount Report."))
  end

  def self.run_report run_by, settings
    self.new.run_duty_discount_report settings
  end

  def self.run_schedulable settings={}
    raise "Email address is required." if settings['email'].blank?
    run_if_configured(settings) do |fiscal_month, fiscal_date|
      self.new.run_duty_discount_report settings, current_fiscal_month:fiscal_month
    end
  end

  def run_duty_discount_report settings, current_fiscal_month:nil
    fiscal_date_start, fiscal_date_end, fiscal_month = get_fiscal_month_dates settings['fiscal_month'], current_fiscal_month

    workbook = nil
    distribute_reads do
      workbook = generate_report fiscal_date_start, fiscal_date_end
    end

    file_name = "PVH_Duty_Discount_US_Fiscal_#{fiscal_month}_#{ActiveSupport::TimeZone[get_time_zone].now.strftime("%Y-%m-%d")}.xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "PVH Duty Discount", file_name: "#{file_name}" do |temp|
        OpenMailer.send_simple_html(settings['email'], "PVH Duty Discount Report", "The duty discount report is attached, covering #{fiscal_date_start} to #{fiscal_date_end}.", temp).deliver_now
      end
    else
      workbook_to_tempfile(workbook, "PVH Duty Discount Savings", file_name: "#{file_name}")
    end
  end

  private
    # Pull month start/end values from the settings, or default to the start/end dates of the fiscal month
    # immediately preceding  the current fiscal month if none are provided.
    def get_fiscal_month_dates fiscal_month_choice, current_fiscal_month
      pvh = Company.where(system_code:"PVH").first
      # Extremely unlikely exception.
      raise "PVH company account could not be found." unless pvh
      if fiscal_month_choice.blank?
        fm = current_fiscal_month ? current_fiscal_month : FiscalMonth.get(pvh, ActiveSupport::TimeZone[get_time_zone].now)
        fm = fm&.back 1
        # This should not be possible unless the FiscalMonth table has not been kept up to date or is misconfigured.
        raise "Fiscal month to use could not be determined." unless fm
        fiscal_month_choice = "#{fm.year}-#{fm.month_number.to_s.rjust(2, "0")}"
      else
        fiscal_year, fiscal_month = fiscal_month_choice.scan(/\w+/).map { |x| x.to_i }
        fm = FiscalMonth.where(company_id: pvh.id, year: fiscal_year, month_number: fiscal_month).first
        # This should not be possible since the screen dropdown contents are based on the FiscalMonth table.
        raise "Fiscal month #{fiscal_month_choice} not found." unless fm
      end
      # These dates are inclusive (i.e. entries with fiscal dates occurring on them should be matched up with this month).
      start_date = fm.start_date.strftime("%Y-%m-%d")
      end_date = fm.end_date.strftime("%Y-%m-%d")
      [start_date, end_date, fiscal_month_choice]
    end

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
        po_line_number, unit_price = get_po_line_values result_set_row, shipments_hash

        tariffs = CommercialInvoiceTariff.where(commercial_invoice_line_id:result_set_row['commercial_invoice_line_id'])
        entered_value = get_entered_value tariffs
        primary_tariff_found = false
        tariffs.order(:hts_code).each do |tar|
          d = PvhReportData.new
          d.entry_number = result_set_row['entry_number']
          d.invoice_number = result_set_row['invoice_number']
          d.transport_mode = result_set_row['transport_mode_code']
          d.po_number = result_set_row['po_number']

          # The value for the "Shipment Number" field varies by mode of transportation.
          ship_mode = result_set_row['transport_mode_code']
          if Entry.get_transport_mode_codes_us_ca("Sea").include?(ship_mode.to_i) || Entry.get_transport_mode_codes_us_ca("Truck").include?(ship_mode.to_i)
            d.shipment_number = result_set_row['container_number']
          else
            d.shipment_number = result_set_row['master_bills_of_lading']
          end

          d.po_line_number = po_line_number
          d.hts_code = tar.hts_code
          # Yes, we are displaying the arrival date as the ETA date instead of the entry's ETA date.  Ops weirdness.
          # It's best not to dwell on it.
          d.eta_date = result_set_row['arrival_date']
          d.vendor_invoice_value = (result_set_row['contract_amount'] || BigDecimal.new(0)).round(2)
          if d.vendor_invoice_value == 0
            d.vendor_invoice_value = (result_set_row['value'] || BigDecimal.new(0)).round(2)
          end
          d.duty_assist_amount = (result_set_row['add_to_make_amount'] || BigDecimal.new(0)).round(2)
          d.dutiable_value = entered_value
          d.dutiable_value_7501 = result_set_row['entered_value_7501'].to_i
          d.duty_rate_pct = ((tar.duty_rate || BigDecimal.new(0)) * BigDecimal.new(100)).round(2)
          d.first_cost_po = (unit_price || BigDecimal.new(0)).round(2)
          d.units_shipped = result_set_row['quantity']
          # Several fields are zero'ed out for supplemental tariff number lines.  If this is not done, invoice
          # line-level quantities can be artificially doubled/tripled/etc.  Only the first non-supplemental tariff
          # line should have these values set.
          if !primary_tariff_found && !tar.special_tariff
            primary_tariff_found = true
          else
            d.base_duty_adj_amount = d.duty_adj_amount
            d.vendor_invoice_value = BigDecimal.new(0)
            d.duty_assist_amount = BigDecimal.new(0)
            d.dutiable_value = BigDecimal.new(0)
            d.dutiable_value_7501 = BigDecimal.new(0)
          end
          raw_data << d
        end
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
      if shipments_hash.has_key? key
        shipments = shipments_hash[key]
      else
        shipments = find_shipments(transport_mode_code, Entry.split_newline_values(master_bills), Entry.split_newline_values(house_bills), force_lookup:true)
        shipments_hash[key] = shipments
      end

      # Invoice number is used only for ocean LCL entries.
      invoice_number = ocean_lcl_entry?(transport_mode_code, result_set_row['fcl_lcl']) ? result_set_row['invoice_number'] : nil
      shipment_line = find_shipment_line(shipments, result_set_row['container_number'], result_set_row['po_number'], result_set_row['part_number'], result_set_row['quantity'], invoice_number: invoice_number)

      order_line = shipment_line&.order_line
      po_line_number = order_line&.line_number
      unit_price = order_line&.price_per_unit
      [po_line_number, unit_price]
    end

    # This method will be made unnecessary when we have a commercial invoice line-level entered value field.
    # What ops is doing currently in multi-tariff scenarios is keying the entered value for just one of the tariffs,
    # and which tariff that is varies depending on the situation.  It is possible, however, for multiple tariffs to
    # have entered values keyed.  This method exists simply to return the sum of the entered values encountered
    # in the provided tariffs.
    def get_entered_value tariffs
      tariffs.map(&:entered_value).compact.sum
    end

    # Condenses the rows in the array together by entry number, returning them as a hash (containing sub-arrays).
    # Also limits the report to rows with duty savings.  Any rows with no duty savings are effectively thrown away by
    # this method.
    def summarize_by_entry_number data_arr
      entry_hash = {}
      data_arr.each do |row|
        if row.duty_savings
          entry_data = entry_hash[row.entry_number]
          if entry_data.nil?
            entry_data = PvhReportData.new
            entry_hash[row.entry_number] = entry_data

            # This data should be consistent through all rows related to the same entry.
            entry_data.entry_number = row.entry_number
            entry_data.eta_date = row.eta_date
            entry_data.transport_mode = row.transport_mode
          end
          entry_data.vendor_invoice_value += row.vendor_invoice_value
          entry_data.duty_assist_amount += row.duty_assist_amount
          entry_data.dutiable_value += row.dutiable_value
          entry_data.dutiable_value_7501 += row.dutiable_value_7501
          entry_data.total_duty_adj_amount += row.duty_adj_amount
          entry_data.total_duty_savings += row.duty_savings
          entry_data.total_duty_difference += row.duty_difference
          entry_data.rows << row
        end
      end
      entry_hash
    end

    # There is no need to condense the overall data on this tab.
    def generate_detail_sheet wb, entry_hash
      sheet = wb.create_sheet "Detail", headers: ["Customs Entry Number", "Vendor Invoice Number", "PO Number",
                                                  "Shipment Number", "PO Line", "HTS Number", "ETA",
                                                  "Vendor Invoice Value", "Duty Assist Amount", "Dutiable Value",
                                                  "Duty Adj Amount", "Duty Savings", "Duty Rate PCT",
                                                  "First Cost - PO", "Units Shipped", "Mode of Transport"]

      entry_hash.each_key do |entry_number|
        summary_row = entry_hash[entry_number]
        styles = [nil, nil, nil, nil, nil, nil, :date, :decimal, :decimal, :decimal, :decimal, :decimal, :decimal, :decimal, :integer, nil]
        summary_row.rows.each do |row|
          values = [row.entry_number, row.invoice_number, row.po_number, row.shipment_number, row.po_line_number,
                    row.hts_code, row.eta_date, row.vendor_invoice_value, row.duty_assist_amount, row.dutiable_value_7501,
                    row.duty_adj_amount, row.duty_savings, row.duty_rate_pct, row.first_cost_po, row.units_shipped, convert_transport_mode(row.transport_mode)]
          wb.add_body_row sheet, values, styles: styles
        end
        # Summary row.
        values = [summary_row.entry_number, nil, nil, nil, nil,
                  nil, nil, summary_row.vendor_invoice_value, summary_row.duty_assist_amount, summary_row.dutiable_value_7501,
                  summary_row.total_duty_adj_amount, summary_row.total_duty_savings, nil, nil, nil, convert_transport_mode(summary_row.transport_mode)]
        summary_styles = [:bold, nil, nil, nil, nil, nil, nil, :bold_decimal, :bold_decimal, :bold_decimal, :bold_decimal, :bold_decimal, nil, nil, nil, :bold]
        wb.add_body_row sheet, values, styles: summary_styles
      end

      wb.set_column_widths sheet, *Array.new(15, 20)

      sheet
    end

    def generate_summary_sheet wb, entry_hash
      sheet = wb.create_sheet "Summary", headers: ["Customs Entry Number", "ETA", "Vendor Invoice Value",
                                                   "Duty Assist Amount", "Dutiable Value", "Duty Difference",
                                                   "Duty Savings", "Mode of Transport"]

      entry_hash.each_value do |row|
        values = [row.entry_number, row.eta_date, row.vendor_invoice_value, row.duty_assist_amount,
                  row.dutiable_value_7501, row.total_duty_difference, row.total_duty_savings, convert_transport_mode(row.transport_mode)]
        styles = [nil, :date, :decimal, :decimal, :decimal, :decimal, :decimal, nil]
        wb.add_body_row sheet, values, styles: styles
      end

      wb.set_column_widths sheet, *Array.new(7, 20)

      sheet
    end

    def assign_styles wb
      wb.create_style :bold, {b:true}
      wb.create_style :decimal, {format_code:"#,##0.00"}
      wb.create_style :integer, {format_code:"#,##0"}
      wb.create_style :bold_decimal, {format_code:"#,##0.00", b:true}
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
            cont.container_number, 
            ent.arrival_date, 
            cil.contract_amount, 
            cil.value,
            cil.entered_value_7501,
            cil.add_to_make_amount, 
            cil.quantity, 
            cil.part_number, 
            cil.id AS commercial_invoice_line_id, 
            ent.transport_mode_code, 
            ent.master_bills_of_lading, 
            ent.house_bills_of_lading, 
            ent.fcl_lcl 
          FROM 
            entries AS ent 
            LEFT OUTER JOIN commercial_invoices AS ci ON 
              ent.id = ci.entry_id 
            LEFT OUTER JOIN commercial_invoice_lines AS cil ON 
              ci.id = cil.commercial_invoice_id 
            LEFT OUTER JOIN orders AS ord ON 
              CONCAT('PVH-',cil.po_number) = ord.order_number AND 
              ent.importer_id = ord.importer_id 
            LEFT OUTER JOIN companies AS factory_company ON 
              ord.factory_id = factory_company.id 
            LEFT OUTER JOIN containers AS cont ON 
              cil.container_id = cont.id 
          WHERE 
            ent.customer_number = 'PVH' AND
            ent.fiscal_date >= '#{fiscal_date_start}' AND 
            ent.fiscal_date <= '#{fiscal_date_end}' AND 
            (
              (cil.contract_amount IS NOT NULL AND cil.contract_amount > 0) OR
              (cil.non_dutiable_amount IS NOT NULL AND cil.non_dutiable_amount > 0)
            )  
          ORDER BY
            ent.entry_number, 
            ci.invoice_number, 
            cil.po_number
      SQL
    end

    def get_time_zone
      "America/New_York"
    end

end; end; end
