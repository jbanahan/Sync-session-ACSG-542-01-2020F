require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'
require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'

module OpenChain; module Report; class PvhFirstCostSavingsReport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
  extend OpenChain::FiscalCalendarSchedulingSupport

  PVH_FIRST_COST_SAVINGS_REPORT_USERS ||= 'pvh_first_cost_savings_report'

  PvhReportData ||= Struct.new(:entry_number, :vendor_name, :factory_name, :po_number, :po_line_number, :shipment,
                               :unit_cost, :units_shipped, :origin, :invoice_number, :hts_code,
                               :duty_rate_pct, :vendor_invoice_value, :customs_value, :total_difference,
                               :total_savings, :base_difference, :customs_entry_date) do
    def initialize
      self.vendor_invoice_value ||= 0.0
      self.customs_value ||= 0.0
      self.total_difference ||= 0.0
      self.total_savings ||= 0.0
    end

    def difference
      self.vendor_invoice_value - self.customs_value
    end

    def savings
      diff = self.base_difference ? self.base_difference : self.difference
      (diff * self.duty_rate_pct / BigDecimal.new(100)).round(2)
    end

    def percent_difference
      if self.vendor_invoice_value != BigDecimal.new(0)
        ((BigDecimal.new(1) - (self.customs_value / self.vendor_invoice_value)) * BigDecimal.new(100)).round(2)
      else
        BigDecimal.new(0)
      end
    end
  end

  def self.permission? user
    user.view_entries? && MasterSetup.get.custom_feature?("PVH First Cost Savings Report") && user.in_group?(Group.use_system_group(PVH_FIRST_COST_SAVINGS_REPORT_USERS, name:"PVH First Cost Savings Report", description:"Users able to run the PVH First Cost Savings Report."))
  end

  def self.run_report run_by, settings
    self.new.run_first_cost_savings_report settings
  end

  def self.run_schedulable settings={}
    raise "Email address is required." if settings['email'].blank?
    self.new.run_first_cost_savings_report settings
  end

  def run_first_cost_savings_report settings
    fiscal_date_start, fiscal_date_end, fiscal_month = get_fiscal_month_dates settings['fiscal_month']

    workbook = nil
    distribute_reads do
      workbook = generate_report fiscal_date_start, fiscal_date_end
    end

    file_name = "PVH_Cost_Savings_for_Fiscal_#{fiscal_month}_#{ActiveSupport::TimeZone[get_time_zone].now.strftime("%Y-%m-%d")}.xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "PVH First Cost Savings", file_name: "#{file_name}" do |temp|
        OpenMailer.send_simple_html(settings['email'], "PVH First Cost Savings Report", "The first cost savings report is attached, covering #{fiscal_date_start} to #{fiscal_date_end}.", temp).deliver_now
      end
    else
      workbook_to_tempfile(workbook, "PVH First Cost Savings", file_name: "#{file_name}")
    end
  end

  private
    # Pull month start/end values from the settings, or default to the start/end dates of the fiscal month
    # immediately preceding  the current fiscal month if none are provided.
    def get_fiscal_month_dates fiscal_month_choice
      pvh = Company.where(system_code:"PVH").first
      # Extremely unlikely exception.
      raise "PVH company account could not be found." unless pvh
      if fiscal_month_choice.blank?
        fm = FiscalMonth.get pvh, ActiveSupport::TimeZone[get_time_zone].now
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
        entered_value_7501 = get_entered_value_7501 tariffs
        primary_tariff_found = false
        tariffs.order(:hts_code).each do |tar|
          d = PvhReportData.new
          d.entry_number = result_set_row['entry_number']
          d.customs_entry_date = result_set_row['release_date']
          d.vendor_name = result_set_row['vendor_name']
          d.factory_name = result_set_row['factory_name']
          d.po_number = result_set_row['po_number']
          d.po_line_number = po_line_number

          # The value for the "Shipment" field varies by mode of transportation.
          ship_mode = result_set_row['transport_mode_code']
          if Entry.get_transport_mode_codes_us_ca("Sea").include? ship_mode.to_i
            d.shipment = result_set_row['container_number']
          elsif Entry.get_transport_mode_codes_us_ca("Air").include? ship_mode.to_i
            d.shipment = result_set_row['master_bills_of_lading']
          end

          d.unit_cost = unit_price
          d.units_shipped = result_set_row['quantity']
          d.origin = result_set_row['country_origin_code']
          d.invoice_number = result_set_row['invoice_number']
          d.hts_code = tar.hts_code
          d.duty_rate_pct = ((tar.duty_rate || BigDecimal.new(0)) * BigDecimal.new(100)).round(2)
          d.vendor_invoice_value = (result_set_row['contract_amount'] || BigDecimal.new(0)).round(2)
          d.customs_value = entered_value_7501
          # Several fields are zero'ed out for supplemental tariff number lines.  If this is not done, invoice
          # line-level quantities can be artificially doubled/tripled/etc.  Only the first non-supplemental tariff
          # line should have these values set.
          if !primary_tariff_found && !tar.special_tariff
            primary_tariff_found = true
          else
            d.base_difference = d.difference
            d.vendor_invoice_value = BigDecimal.new(0)
            d.customs_value = BigDecimal.new(0)
          end
          raw_data << d
        end
      end

      generate_detail_sheet wb, raw_data
      generate_summary_sheet wb, raw_data

      wb
    end

    def get_po_line_values result_set_row, shipments_hash
      # Involving a hash because there could be many lines per entry, and the shipments look-up is entry-level.
      transport_mode_code = result_set_row['transport_mode_code']
      master_bills = result_set_row['ent_master_bills_of_lading']
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
    def get_entered_value_7501 tariffs
      tariffs.map(&:entered_value_7501).compact.sum
    end

    # There is no need to condense the overall data on this tab.
    def generate_detail_sheet wb, data_arr
      sheet = wb.create_sheet "Detail", headers: ["Entry Number", "Customs Entry Date", "Vendor Name", "Factory Name",
                                                  "PO Number", "PO Line Number", "Shipment", "Unit Cost (PO)",
                                                  "Units Shipped", "Origin", "Invoice Number", "HTS Code",
                                                  "Duty Rate PCT", "Vendor Invoice Value", "Customs Value",
                                                  "Difference", "Savings", "% Difference"]

      data_arr.each do |row|
        values = [row.entry_number, row.customs_entry_date, row.vendor_name, row.factory_name, row.po_number,
                  row.po_line_number, row.shipment, row.unit_cost, row.units_shipped, row.origin, row.invoice_number,
                  row.hts_code, row.duty_rate_pct, row.vendor_invoice_value, row.customs_value, row.difference,
                  row.savings, row.percent_difference]
        styles = [nil, nil, nil, nil, nil, nil, nil, :decimal, :integer, nil, nil, nil, :decimal, :decimal, :decimal,
                  :decimal, :decimal, :decimal]
        wb.add_body_row sheet, values, styles: styles
      end

      wb.set_column_widths sheet, *Array.new(17, 20)

      sheet
    end

    def generate_summary_sheet wb, data_arr
      sheet = wb.create_sheet "Summary", headers: ["Vendor Name", "Factory Name", "Origin", "Co", "Entry Number",
                                                   "Vendor Invoice Value", "Customs Value", "Difference", "Savings"]
      entry_hash = {}
      data_arr.each do |row|
        entry_data = entry_hash[row.entry_number]
        if entry_data.nil?
          entry_data = PvhReportData.new
          entry_hash[row.entry_number] = entry_data

          # This data should be consistent through all rows related to the same entry.
          entry_data.vendor_name = row.vendor_name
          entry_data.factory_name = row.factory_name
          entry_data.origin = row.origin
          # Only the first two characters of the PO number are shown in the "CO" column.  We're reusing the PO number
          # field in the condensed entry data object out of convenience.
          entry_data.po_number = row.po_number.try(:[], 0, 2)
          entry_data.entry_number = row.entry_number
        end
        entry_data.vendor_invoice_value += row.vendor_invoice_value
        entry_data.customs_value += row.customs_value
        entry_data.total_difference += row.difference
        entry_data.total_savings += row.savings
      end

      entry_hash.each_value do |row|
        values = [row.vendor_name, row.factory_name, row.origin, row.po_number, row.entry_number,
                  row.vendor_invoice_value, row.customs_value, row.total_difference, row.total_savings]
        styles = [nil, nil, nil, nil, nil, :decimal, :decimal, :decimal, :decimal]
        wb.add_body_row sheet, values, styles: styles
      end

      wb.set_column_widths sheet, *Array.new(9, 20)

      sheet
    end

    def assign_styles wb
      wb.create_style(:decimal, {format_code: "#,##0.00"})
      wb.create_style(:integer, {format_code: "#,##0"})
    end

    def make_query fiscal_date_start, fiscal_date_end
      <<-SQL
        SELECT
          ent.entry_number, 
          ent.release_date, 
          cil.vendor_name, 
          factory_company.name AS factory_name, 
          cil.po_number, 
          cont.container_number, 
          ci.master_bills_of_lading, 
          ent.transport_mode_code, 
          cil.quantity, 
          cil.country_origin_code, 
          ci.invoice_number, 
          cil.contract_amount, 
          cil.part_number, 
          cil.id AS commercial_invoice_line_id, 
          ent.master_bills_of_lading as ent_master_bills_of_lading, 
          ent.house_bills_of_lading, 
          ent.fcl_lcl 
        FROM 
          entries AS ent 
          INNER JOIN commercial_invoices AS ci ON 
            ent.id = ci.entry_id 
          INNER JOIN commercial_invoice_lines AS cil ON 
            ci.id = cil.commercial_invoice_id 
          LEFT OUTER JOIN orders AS ord ON 
            CONCAT('PVH-', cil.po_number) = ord.order_number AND 
            ent.importer_id = ord.importer_id 
          LEFT OUTER JOIN companies AS factory_company ON 
            ord.factory_id = factory_company.id 
          LEFT OUTER JOIN containers AS cont ON 
            cil.container_id = cont.id 
        WHERE 
          ent.customer_number = 'PVH' AND 
          ent.fiscal_date >= '#{fiscal_date_start}' AND 
          ent.fiscal_date <= '#{fiscal_date_end}' AND 
          cil.first_sale = true
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