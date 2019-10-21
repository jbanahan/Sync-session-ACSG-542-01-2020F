require 'open_chain/custom_handler/ascena/ascena_report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Ascena; class AscenaVendorScorecardReport
  extend OpenChain::FiscalCalendarSchedulingSupport
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::Ascena::AscenaReportHelper

  AscenaVendorScorecardRow ||= Struct.new(:vendor_name, :vendor_id, :factory_name, :factory_id, :entry_number, :first_sale_eligible_date,
                                          :first_release_date, :invoice_number, :invoice_line_value, :product_line, :po_number, :part_number,
                                          :contract_amount, :invoice_value_contract, :duty_savings_first_sale)

  HEADER_FORMAT ||= XlsMaker.create_format "Bolded", weight: :bold, align: :merge, size: 16
  MONEY_FORMAT ||= XlsMaker.create_format "Money", :number_format => '$#,##0.00'
  CENTER_FORMAT ||= XlsMaker.create_format "Centered", :horizontal_align => :center

  def self.cust_info
    CUST_INFO.select{ |ci| [ASCENA_CUST_NUM, MAURICES_CUST_NUM].include? ci[:cust_num] }
  end

  def self.run_report run_by, settings
    self.new.run_scorecard_report settings
  end

  def self.run_schedulable settings
    settings['email_to'] = Array.wrap(settings['email_to'])
    settings['cust_numbers'] = Array.wrap(settings['cust_numbers'])
    raise "Scheduled instances of the Vendor Scorecard Report must include an email_to setting with an array of email addresses." unless settings['email_to'].length > 0
    raise "Scheduled instances of the Vendor Scorecard Report must include a cust_numbers setting with at least one customer number." unless settings['cust_numbers'].length > 0
    # sets the fiscal calendar
    settings['company'] = 'ASCENA'
    run_if_configured(settings) do |current_fiscal_quarter_start_month, fiscal_date|
      # Get the previous quarter.  We're running the report over that, not the current quarter, which is what gets
      # returned by run_if_configured.
      prev_fiscal_quarter_start_month = current_fiscal_quarter_start_month.back 3
      prev_fiscal_quarter_end_month = current_fiscal_quarter_start_month.back 1
      if prev_fiscal_quarter_end_month && prev_fiscal_quarter_end_month
        temp = nil
        begin
          settings['range_field'] = 'first_release_date'
          settings['start_release_date'] = prev_fiscal_quarter_start_month.start_date
          settings['end_release_date'] = prev_fiscal_quarter_end_month.end_date
          quarter_descriptor = "Q#{(((prev_fiscal_quarter_start_month.month_number - 1) / 3) + 1)} #{prev_fiscal_quarter_start_month.year}"
          cust_names = cust_nums_to_short_names settings["cust_numbers"]
          report_descriptor = "#{cust_names} Vendor Scorecard [#{quarter_descriptor}]"
          settings['file_name'] = report_descriptor
          temp = self.new.run_scorecard_report settings
          OpenMailer.send_simple_html(settings['email_to'], "[VFI Track] #{report_descriptor}", "Attached is the #{cust_names} Vendor Scorecard Report for #{quarter_descriptor}, #{prev_fiscal_quarter_start_month.start_date.strftime("%m/%d/%Y")} - #{prev_fiscal_quarter_end_month.end_date.strftime("%m/%d/%Y")}.", [temp]).deliver_now
        ensure
          temp.close! if temp && !temp.closed?
        end
      end
    end
  end

  def run_scorecard_report settings
    start_date, end_date = get_dates settings
    workbook = generate_report start_date, end_date, settings['range_field'], settings['cust_numbers']
    file_name = settings['file_name'].presence || get_on_demand_file_name(start_date, end_date, settings['cust_numbers'])
    workbook_to_tempfile(workbook, "VendorScorecard", file_name: "#{file_name}.xls")
  end

  def get_dates settings
    if settings['range_field'] == 'first_release_date'
      start_date, end_date = sanitize_start_end_dates(settings['start_release_date'], settings['end_release_date'], 'America/New_York')
    elsif settings['range_field'] == 'fiscal_date'
      start_date, end_date = fiscal_month_dates(*settings['start_fiscal_year_month'].split('-'), *settings['end_fiscal_year_month'].split('-'))
    end
    [start_date, end_date]
  end

  def sanitize_start_end_dates start_date, end_date, time_zone
    start_date = sanitize_date_string start_date, time_zone
    end_date = sanitize_date_string end_date, time_zone
    [start_date, end_date]
  end

  def get_on_demand_file_name start_date, end_date, cust_nums
    "#{self.class.cust_nums_to_short_names cust_nums} Vendor Scorecard [#{Date.parse(start_date.to_s).strftime("%m-%d-%Y")} - #{Date.parse(end_date.to_s).strftime("%m-%d-%Y")}]"
  end

  def generate_report start_date, end_date, range_field, cust_nums
    wb = XlsMaker.new_workbook

    data_arr = []
    result_set = ActiveRecord::Base.connection.exec_query make_query(start_date, end_date, range_field, cust_nums)
    result_set.each do |result_set_row|
      row = AscenaVendorScorecardRow.new
      row.vendor_name = result_set_row['vendor_name']
      row.vendor_id = result_set_row['vendor_id']
      row.factory_name = result_set_row['factory_name']
      row.factory_id = result_set_row['factory_id']
      row.entry_number = result_set_row['entry_number']
      row.first_sale_eligible_date = result_set_row['first_sale_eligible_date']
      row.first_release_date = result_set_row['first_release_date']
      row.invoice_number = result_set_row['invoice_number']
      row.invoice_line_value = result_set_row['invoice_line_value']
      row.product_line = result_set_row['product_line']
      row.po_number = result_set_row['po_number']
      row.part_number = result_set_row['part_number']
      row.contract_amount = result_set_row['contract_amount']
      row.invoice_value_contract = result_set_row['invoice_value_contract']
      row.duty_savings_first_sale = result_set_row['duty_savings_first_sale']
      data_arr.push row
    end

    generate_vendor_summary_sheet wb, data_arr
    generate_factory_summary_sheet wb, data_arr
    generate_data_sheet wb, data_arr

    wb
  end

  def generate_vendor_summary_sheet wb, data_arr
    sheet = XlsMaker.create_sheet wb, "Vendor", []

    XlsMaker.add_body_row sheet, 0, ["<Summary by vendor>", "", "", "", "", ""]
    sheet.row(0).height = 20
    XlsMaker.set_cell_formats sheet, 0, [HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT]
    XlsMaker.add_header_row sheet, 2, ["No.", "VENDOR", "SUM OF INV AMOUNT", "SUM OF FS INV AMOUNT", "SUM OF SAVINGS", "PENETRATION"]
    penetration_format = XlsMaker.create_format "Penetration", :number_format => '0%'

    # Condense data by vendor.
    data_hash = condense_data_by_vendor data_arr

    counter = 1
    total_invoice_amount = 0
    total_invoice_in_fs_eligible = 0
    total_fs_savings = 0
    data_hash.each_value do |row|
      # Exclude vendors that don't have any first sale eligible factories.  We're assessing this by the presence/absence of
      # a first sale eligible date (pulled from data cross references).
      if !row.first_sale_eligible_date.nil?
        penetration = ((row.contract_amount / row.invoice_value_contract * 100) / 100).round(2)
        XlsMaker.add_body_row sheet, counter + 2, [counter, row.vendor_name, row.invoice_value_contract, row.contract_amount, row.duty_savings_first_sale, penetration]
        XlsMaker.set_cell_formats sheet, counter + 2, [CENTER_FORMAT, nil, MONEY_FORMAT, MONEY_FORMAT, MONEY_FORMAT, penetration_format]
        total_invoice_amount += row.invoice_value_contract
        total_invoice_in_fs_eligible += row.contract_amount
        total_fs_savings += row.duty_savings_first_sale
        counter += 1
      end
    end
    # Totals row
    total_penetration = total_invoice_amount != 0 ? ((total_invoice_in_fs_eligible / total_invoice_amount * 100) / 100).round(2) : 0
    XlsMaker.add_body_row sheet, counter + 2, ["", "TOTAL", total_invoice_amount, total_invoice_in_fs_eligible, total_fs_savings, total_penetration]
    XlsMaker.set_cell_formats sheet, counter + 2, [nil, nil, MONEY_FORMAT, MONEY_FORMAT, MONEY_FORMAT, penetration_format]

    XlsMaker.set_column_widths sheet, [8, 50, 15, 28, 15, 15]

    sheet
  end

  def condense_data_by_vendor data_arr
    data_hash = Hash.new
    data_arr.each do |data_row|
      row = data_hash[data_row.vendor_id]
      if row.nil?
        row = AscenaVendorScorecardRow.new
        row.vendor_id = data_row.vendor_id
        row.vendor_name = data_row.vendor_name
        row.invoice_value_contract = 0.00
        row.contract_amount = 0.00
        row.duty_savings_first_sale = 0.00
        data_hash[data_row.vendor_id] = row
      end
      # Allow this value to be set if even one row under the vendor is first sale eligible.
      if row.first_sale_eligible_date.nil?
        row.first_sale_eligible_date = parse_first_sale_eligible_date data_row
      end
      row.invoice_value_contract += data_row.invoice_value_contract
      row.contract_amount += data_row.contract_amount
      row.duty_savings_first_sale += data_row.duty_savings_first_sale
    end
    data_hash
  end

  def generate_factory_summary_sheet wb, data_arr
    sheet = XlsMaker.create_sheet wb, "Vendor Factory Pair", []

    XlsMaker.add_body_row sheet, 0, ["<Summary by vendor / factory pair>", "", "", "", "", "", ""]
    sheet.row(0).height = 20
    XlsMaker.set_cell_formats sheet, 0, [HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT]
    XlsMaker.add_header_row sheet, 2, ["No.", "VENDOR", "FACTORY", "SUM OF INV AMOUNT", "SUM OF FS INV AMOUNT", "SUM OF SAVINGS", "REMARKS"]

    # Condense data by vendor and factory.
    data_hash = Hash.new
    data_arr.each do |data_row|
      hash_key = "#{data_row.vendor_id}~#{data_row.factory_id}"
      row = data_hash[hash_key]
      if row.nil?
        row = AscenaVendorScorecardRow.new
        row.vendor_name = data_row.vendor_name
        row.vendor_id = data_row.vendor_id
        row.factory_name = data_row.factory_name
        row.factory_id = data_row.factory_id
        row.invoice_value_contract = 0
        row.contract_amount = 0
        row.duty_savings_first_sale = 0
        data_hash[hash_key] = row
      end
      if row.first_sale_eligible_date.nil?
        row.first_sale_eligible_date = parse_first_sale_eligible_date data_row
      end
      row.invoice_value_contract += data_row.invoice_value_contract
      row.contract_amount += data_row.contract_amount
      row.duty_savings_first_sale += data_row.duty_savings_first_sale
    end

    # Also condense data by vendor.  This is used for first sale eligibility filtration.
    vendor_hash = condense_data_by_vendor data_arr

    counter = 1
    total_invoice_amount = 0
    total_invoice_in_fs_eligible = 0
    total_fs_savings = 0
    data_hash.each_value do |row|
      # Exclude vendors that don't have any first sale eligible factories.  We're assessing this by the presence/absence of
      # a first sale eligible date (pulled from data cross references).
      if !vendor_hash[row.vendor_id].first_sale_eligible_date.nil?
        first_sale_eligibility_remarks = get_first_sale_eligibility_remarks row.first_sale_eligible_date
        XlsMaker.add_body_row sheet, counter + 2, [counter, row.vendor_name, row.factory_name, row.invoice_value_contract, row.contract_amount, row.duty_savings_first_sale, first_sale_eligibility_remarks]
        XlsMaker.set_cell_formats sheet, counter + 2, [CENTER_FORMAT, nil, nil, MONEY_FORMAT, MONEY_FORMAT, MONEY_FORMAT, nil]
        total_invoice_amount += row.invoice_value_contract
        total_invoice_in_fs_eligible += row.contract_amount
        total_fs_savings += row.duty_savings_first_sale
        counter += 1
      end
    end
    # Totals row
    XlsMaker.add_body_row sheet, counter + 2, ["", "TOTAL", "", total_invoice_amount, total_invoice_in_fs_eligible, total_fs_savings, ""]
    XlsMaker.set_cell_formats sheet, counter + 2, [nil, nil, nil, MONEY_FORMAT, MONEY_FORMAT, MONEY_FORMAT, nil]

    XlsMaker.set_column_widths sheet, [8, 50, 50, 15, 28, 15, 18]

    sheet
  end

  # The first sale eligible date is stored in a weird manner: in a string value field in the data cross references table.
  # This method handles the unlikely case where that field contains a non-legit date (or, at least, not in the format we're expecting).
  def parse_first_sale_eligible_date rs_row
    begin
      first_sale_eligible_date = rs_row.first_sale_eligible_date.nil? ? nil : Date.strptime(rs_row.first_sale_eligible_date, '%Y-%m-%d')
    rescue ArgumentError
      first_sale_eligible_date = nil
    end
    first_sale_eligible_date
  end

  def get_first_sale_eligibility_remarks first_sale_eligible_date
    if first_sale_eligible_date.nil?
      remarks = "Ineligible"
    else
      # January 1, 2017 was the date eligibility started to be recorded in VFI Track.  It's not really when some of
      # these vendors became eligible.  Ascena wants a default label to be shown if the default date is encountered.
      if first_sale_eligible_date == Date.parse('01/01/2017', '%m/%d/%Y')
        remarks = "Eligible < 2017"
      else
        remarks = "Eligible - #{first_sale_eligible_date.strftime('%m/%d/%Y')}"
      end
    end
    remarks
  end

  def generate_data_sheet wb, data_arr
    sheet = XlsMaker.create_sheet wb, "Data", []

    XlsMaker.add_body_row sheet, 0, ["<Detailed Data Lines>", "", "", "", "", "", "", "", "", "", "", "", "", ""]
    sheet.row(0).height = 20
    XlsMaker.set_cell_formats sheet, 0, [HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT, HEADER_FORMAT]
    XlsMaker.add_header_row sheet, 2, ["No.", "VENDOR", "FACTORY", "ENTRY NUMBER", "INV AMOUNT", "FS SAVINGS", "FIRST RELEASE DATE", "INVOICE NUMBER", "VALUE", "PRODUCT LINE", "PO NUMBER", "PART NUMBER", "CONTRACT AMOUNT", "REMARKS"]

    # There is no need to condense the overall data on this tab.  We're already condensing by entry in the query.
    # We do need a hash of data condensed by vendor for first sale eligibility filtration, however.  Rows whose vendor
    # is deemed not to be FS-eligible by this hash won't be shown on the report.
    vendor_hash = condense_data_by_vendor data_arr

    counter = 1
    data_arr.each do |row|
      # Exclude vendors that don't have any first sale eligible factories.  We're assessing this by the presence/absence of
      # a first sale eligible date (pulled from data cross references).
      if !vendor_hash[row.vendor_id].first_sale_eligible_date.nil?
        first_release_date = row.first_release_date.strftime('%m/%d/%Y')
        first_sale_eligibility_remarks = get_first_sale_eligibility_remarks parse_first_sale_eligible_date(row)
        XlsMaker.add_body_row sheet, counter + 2, [counter, row.vendor_name, row.factory_name, row.entry_number, row.invoice_value_contract, row.duty_savings_first_sale, first_release_date, row.invoice_number, row.invoice_line_value, row.product_line, row.po_number, row.part_number, row.contract_amount, first_sale_eligibility_remarks]
        XlsMaker.set_cell_formats sheet, counter + 2, [CENTER_FORMAT, nil, nil, nil, MONEY_FORMAT, MONEY_FORMAT, nil, nil, MONEY_FORMAT, nil, nil, nil, MONEY_FORMAT, nil]
        counter += 1
      end
    end

    XlsMaker.set_column_widths sheet, [8, 50, 50, 18, 15, 15, 22, 18, 13, 15, 15, 15, 20, 18]

    sheet
  end

  def make_query date_start, date_end, range_field, cust_nums
    qry = <<-SQL
              SELECT 
                vendor.name AS 'vendor_name', 
                ord.vendor_id, 
                factory.name AS 'factory_name', 
                ord.factory_id, 
                ent.entry_number, 
                first_sale_xref.value AS 'first_sale_eligible_date', 
                ent.first_release_date, 
                ci.invoice_number,
                cil.value AS 'invoice_line_value', 
                cil.product_line, 
                cil.po_number, 
                cil.part_number, 
                cil.contract_amount, 
                #{invoice_value_contract('cil')} AS 'invoice_value_contract',
                #{duty_savings_first_sale('cil')} AS 'duty_savings_first_sale' 
              FROM
                commercial_invoices AS ci
                INNER JOIN commercial_invoice_lines cil ON 
                  ci.id = cil.commercial_invoice_id
                INNER JOIN entries AS ent ON 
                  ci.entry_id = ent.id 
                INNER JOIN orders AS ord ON 
                  ord.order_number = IF(ent.customer_number = 'ASCE', CONCAT('ASCENA-', cil.product_line, '-', cil.po_number), CONCAT('ASCENA-MAU-', cil.po_number))
                INNER JOIN companies AS vendor ON 
                  ord.vendor_id = vendor.id
                INNER JOIN companies AS factory ON 
                  ord.factory_id = factory.id
                LEFT OUTER JOIN data_cross_references AS first_sale_xref ON 
                  cil.mid = SUBSTRING_INDEX(first_sale_xref.key, '-', 1) AND 
                  vendor.system_code = SUBSTRING_INDEX(first_sale_xref.key, '-', -1) AND 
                  first_sale_xref.cross_reference_type = 'asce_mid'
              WHERE
                ent.customer_number IN (?) AND
                ent.#{range_field} IS NOT NULL AND 
                ent.#{range_field} >= ? AND 
                ent.#{range_field} < ?
              ORDER BY 
                vendor.name, 
                factory.name, 
                ent.entry_number, 
                ci.invoice_number, 
                cil.product_line
          SQL
    ActiveRecord::Base.sanitize_sql_array([qry, cust_nums, date_start, date_end])
  end

end; end; end; end
