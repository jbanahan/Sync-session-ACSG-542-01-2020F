require 'open_chain/fiscal_calendar_scheduling_support'
require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'
require 'open_chain/report/report_helper'

module OpenChain; module CustomHandler; module Pvh; class PvhDutyAssistReport
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
  extend OpenChain::Report::ReportHelper
  extend OpenChain::FiscalCalendarSchedulingSupport

  CUST_NUMBERS ||= {"PVHCANADA" => "833231749RM0001", "PVH" => "PVH"}.freeze

  PVH_DUTY_DISCOUNT_REPORT_USERS ||= 'pvh_duty_discount_report'.freeze

  def self.fiscal_month(settings, company_id)
    if settings['fiscal_month'].to_s =~ /(\d{4})-(\d{2})/
      year = Regexp.last_match 1
      month = Regexp.last_match 2
      FiscalMonth.where(company_id: company_id, year: year.to_i, month_number: month.to_i).first
    end
  end

  def self.us
    Company.importers.with_customs_management_number(CUST_NUMBERS['PVH']).first
  end

  def self.canada
    Company.importers.with_fenix_number(CUST_NUMBERS['PVHCANADA']).first
  end

  def self.permission?(user)
    user.view_entries? && MasterSetup.get.custom_feature?("WWW VFI Track Reports") &&
      (user.company.master? || user.in_group?(Group.use_system_group(PVH_DUTY_DISCOUNT_REPORT_USERS, name: "PVH Duty Discount Report",
                                                                                                     description: "Users able to run the PVH Duty Discount Report.")))
  end

  def self.run_report _run_by, settings = {}
    cust_number = CUST_NUMBERS[settings['cust_number']]

    company = company_lookup(cust_number)

    fm = fiscal_month(settings, company.id)

    raise "No fiscal month configured for #{settings['cust_number']}" unless fm

    wb = self.new.run(fm.year, fm.month_number, settings['cust_number'])

    file_name = "#{cust_number}_Duty Assist Data Dump_Fiscal_#{fm.start_date.strftime('%Y-%m')}_#{Time.zone.today.strftime('%Y-%m-%d')}.xlsx"
    xlsx_workbook_to_tempfile(wb, "Duty Assist", file_name: file_name)
  end

  def self.company_lookup(cust_number)
    company = Company.importers.with_customs_management_number(cust_number).first
    company ||= Company.importers.with_fenix_number(cust_number).first
    company
  end

  def self.run_schedulable config = {}
    config['email'] = Array.wrap(config['email'])
    raise "Scheduled instances of the PVH / PVH Canada Duty Assist Report must include an email setting with at least one email address." unless config['email'].length > 0
    raise "Scheduled instances of the PVH / PVH Canada Duty Assist Report must include a cust_number setting." if config['cust_number'].blank?

    cust_number = CUST_NUMBERS[config['cust_number']]

    company = company_lookup(cust_number)

    raise "No company found with customer number: #{config['cust_number']}" if company.blank?

    config['company'] = company
    run_if_configured(config) do |fiscal_month, _fiscal_date|
      fm = fiscal_month.back(1)
      report = self.new.run(fm.year, fm.month_number, config['cust_number'])
      cust_number = config['cust_number']
      file_name = "#{cust_number}_Data_Dump_Fiscal_#{fiscal_month.start_date.strftime('%Y-%m')}_#{Time.zone.today.strftime('%Y-%m-%d')}.xlsx"
      report = xlsx_workbook_to_tempfile(report, "Duty Assist", file_name: file_name)
      body = if cust_number == "PVH"
                 "Attached is the \"PVH Duty Dump Report, #{fm.year}-#{fm.month_number}\" based on ACH Due Date."
             else
                 "Attached is the \"PVHCANADA Duty Dump Report, #{fm.year}-#{fm.month_number}\" based on CADEX Acceptance Date."
             end
      OpenMailer.send_simple_html(config['email'], "#{cust_number} Data Dump #{fm.year}-#{fm.month_number}", body, report).deliver_now
    end
  end

  def run fiscal_year, fiscal_month, customer_number
    build_report(entries(fiscal_year, fiscal_month, customer_number), customer_number, fiscal_month)
  end

  def write_report wb, path
    File.open(path, "wb") { wb.write path }
  end

  def build_report entry_ids, customer_number, _fiscal_month
    us_entries = (customer_number == "PVH")

    wb = builder
    decimal_style = wb.create_style :decimal, {format_code: "#,##0.00"}
    us_styles = [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, decimal_style, decimal_style, decimal_style,
                 decimal_style, decimal_style, decimal_style, decimal_style, nil, nil, nil, nil, nil]
    sheet = wb.create_sheet("Results", headers: (us_entries ? us_headers : ca_headers))
    wb.freeze_horizontal_rows(sheet, 1)
    Array.wrap(entry_ids).each do |id|
      entry = Entry.where(id: id).first
      preload_entry(entry)

      # Skip anything that hasn't been invoiced yet
      next if entry.broker_invoices.length == 0

      shipments = find_shipments(entry.transport_mode_code,
                                 Entry.split_newline_values(entry.master_bills_of_lading),
                                 Entry.split_newline_values(entry.house_bills_of_lading),
                                 force_lookup: true)
      preload_shipments(shipments)
      entry.commercial_invoices.each do |invoice|
        invoice.commercial_invoice_lines.each do |invoice_line|
          shipment_line = lookup_shipment_line(shipments, entry, invoice, invoice_line)
          row = if us_entries
                  generate_us_report_row(entry, invoice, invoice_line, shipment_line)
                else
                  generate_ca_report_row(entry, invoice, invoice_line, shipment_line)
                end
          # We need a special format for US rows so we check which row type
          if us_entries
            wb.add_body_row(sheet, row, styles: us_styles) if row.present?
          else
            wb.add_body_row(sheet, row) if row.present? # rubocop:disable Style/IfInsideElse
          end
        end
      end
    end

    wb
  end

  def entries fiscal_year, fiscal_month, customer_number
    Entry.where(customer_number: customer_number, fiscal_year: fiscal_year, fiscal_month: fiscal_month).order(:release_date).pluck(:id)
  end

  def preload_entry entry
    ActiveRecord::Associations::Preloader.new.preload(entry, [:broker_invoices, {commercial_invoices: {commercial_invoice_lines: [:commercial_invoice_tariffs, :container]}}])
  end

  def preload_shipments shipments
    shipments.each do |shipment|
      ActiveRecord::Associations::Preloader.new.preload(shipment, [{containers: [shipment_lines: [:product, {piece_sets: [{order_line: [:order, :product]}]}]],
                                                                    shipment_lines: [:product, {piece_sets: [{order_line: [:order, :product]}]}]}])
    end
  end

  def builder
    XlsxBuilder.new
  end

  def us_headers
    [
      "Entry Number", # A
      "Invoice Number", # B
      "Country Of Origin", # C
      "PO", # D
      "PO Line", # E
      "Entry Date", # F
      "Import Date", # G
      "Product Description/Style Description", # H
      "Master Bills", # I
      "Arrival Date", # J
      "Vendor Invoice Value", # K
      "Dutiable Assist", # L
      "Dutiable Value", # M
      "Duty Adj Amt", # N
      "Duty Savings", # O
      "Duty Rate", # P
      "Price / Unit", # Q
      "Invoice Quantity", # R
      "Exchange Rate", # S
      "HTS", # T
      "301 HTS", # U
      "CN Rate" # V
    ]
  end

  def generate_us_report_row entry, invoice, invoice_line, shipment_line
    primary_tariff = find_primary_tariff(invoice_line)
    tariff_301 = find_301_tariff(invoice_line)

    row = []
    return row if primary_tariff.blank?

    row << entry.entry_number # A
    row << invoice.invoice_number # B
    row << invoice_line.country_origin_code # C
    row << invoice_line.po_number # D
    row << shipment_line&.order_line&.line_number # E
    row << in_timezone(entry.entry_filed_date).strftime("%m/%d/%Y") # F
    row << entry.import_date.strftime("%m/%d/%Y") # G
    row << primary_tariff.tariff_description # H
    row << shipment_number(entry, invoice_line, shipment_line) # I
    row << in_timezone(entry.arrival_date).strftime("%m/%d/%Y") # J

    dutiable_value = invoice_line.commercial_invoice_tariffs.map { |t| ensure_numeric(t.entered_value) }.sum
    vendor_invoice_value = ensure_numeric(invoice_line.value_foreign)
    duty_assist_amount = ensure_numeric(invoice_line.add_to_make_amount)
    line_value = ensure_numeric(invoice_line.value)
    duty_savings = (dutiable_value - vendor_invoice_value - duty_assist_amount).round(2)
    duty_rate = ensure_numeric(primary_tariff.duty_rate)
    price_per_unit = ensure_numeric(shipment_line&.order_line&.price_per_unit).round(2)

    row << line_value # K
    row << duty_assist_amount # L
    row << dutiable_value # M
    if invoice_line.first_sale # N
      row << BigDecimal("0.00")
    else
      row << duty_savings
    end
    # Duty Adjustment amount is negative (.ie they reduced duty by X amount)
    # but the savings should be a positive amount
    row << ((duty_savings * -1) * duty_rate).round(2) # O
    row << (duty_rate * 100).round(2) # P
    row << price_per_unit # Q
    row << invoice_line.quantity # R
    row << invoice.exchange_rate # S
    row << primary_tariff.hts_code # T
    row << tariff_301&.hts_code # U
    row << (ensure_numeric(tariff_301&.duty_rate) * 100).round(2) # V

    row
  end

  def special_tariff? tariff
    ['9902', '9903'].include?(tariff.hts_code.to_s[0..3])
  end

  def find_primary_tariff invoice_line
    invoice_line.commercial_invoice_tariffs.find {|t| !special_tariff?(t) }
  end

  def find_301_tariff invoice_line
    invoice_line.commercial_invoice_tariffs.find {|t| t.hts_code.to_s.starts_with?("9903") }
  end

  def ensure_numeric value
    value.nil? ? BigDecimal("0") : value
  end

  def shipment_number entry, invoice_line, shipment_line
    number = nil
    if Entry.get_transport_mode_codes_us_ca("Air").include? entry.transport_mode_code.to_i
      number = Entry.split_newline_values(entry.master_bills_of_lading).first
    else
      # It's possible that the shipment line is nil (if the invoice line doesn't match to an ASN)
      # In that case, it's possible that the invoice line may have the container number too.
      number = shipment_line&.container&.container_number

      if number.blank?
        number = invoice_line.container&.container_number
      end

      # One last ditch effort we can make here is see if the entry only has a single container on it,
      # if so, then we can use that value.
      if number.blank?
        containers = Entry.split_newline_values(entry.master_bills_of_lading)
        if containers.length == 1
          number = containers.first
        end
      end
    end

    number
  end

  def entered_value invoice_line
    # This field is somewhat new, so some of these lines may not have the value, fall back then to summing the
    # 7501 value at the tariff level
    value = invoice_line.entered_value_7501.to_i
    if value == 0
      value = invoice_line.commercial_invoice_tariffs.map(&:entered_value_7501).compact.sum
    end

    BigDecimal(value)
  end

  def ca_headers
    [
      "Entry #", # A
      "Invoice #", # B
      "PO", # C
      "Shipment #", # D
      "PO Line", # E
      "Release Date", # F
      "ETA", # G
      "Entry Date", # H
      "Import Date", # I
      "Style #", # J
      "Country of Origin", # K
      "Product Description", # L
      "HTS #", # M
      "Currency Type", # N
      "Exchange Rate", # O
      "Vendor Invoice Value Calculated (USD)", # P
      "Invoice Tariff Entered Value (CAD)", # Q
      "Duty Assist Amt (USD)", # R
      "Duty Deductions (USD)", # S
      "Dutiable Value (USD)", # T
      "Duty Rate PCT", # U
      "Duty Adj Amt (USD)", # V
      "Duty Savings (USD)", # W
      "First Cost - PO (USD)", # X
      "Units Shipped" # Y
    ]
  end

  def generate_ca_report_row entry, invoice, invoice_line, shipment_line
    # Canada only has 1 tariff line...so to keep the looping logic equivalent for
    # US / Canada just pull the tariff out of the invoice line here.
    tariff = invoice_line.commercial_invoice_tariffs.first

    row = []
    return row if tariff.blank?

    row << entry.entry_number # A
    row << invoice.invoice_number # B
    row << invoice_line.po_number # C
    row << shipment_number(entry, invoice_line, shipment_line) # D
    row << shipment_line&.order_line&.line_number # E
    row << in_timezone(entry.release_date).strftime("%m/%d/%Y") # F

    if entry.eta_date
      row << entry.eta_date.strftime("%m/%d/%Y") # G
    else
      row << in_timezone(entry.release_date).to_date.strftime("%m/%d/%Y") # G
    end

    row << in_timezone(entry.across_sent_date).strftime("%m/%d/%Y") # H

    # Arrival date used to literally be a copy of the release date.  It is now populated for Canada
    # independently from another date source.  Therefore to maintain the continuation of the same value in release and arrival
    # we're just going to continue to use release date as the column source.
    row << in_timezone(entry.release_date).strftime("%m/%d/%Y") # I
    row << invoice_line.part_number # J
    row << invoice_line.country_origin_code # K
    row << tariff.tariff_description # L
    row << tariff.hts_code # M
    row << invoice.currency # N

    exchange_rate = ensure_numeric(invoice.exchange_rate)
    invoice_value = ensure_numeric(invoice_line.value)
    entered_value = ensure_numeric(tariff.entered_value)
    duty_assists = ensure_numeric(invoice_line.add_to_make_amount)
    duty_deductions = ensure_numeric(invoice_line.miscellaneous_discount) * BigDecimal(-1)
    duty_rate = ensure_numeric(tariff.duty_rate)
    dutiable_value = (invoice_value + duty_assists + duty_deductions)

    row << exchange_rate # O
    row << invoice_value # P
    row << entered_value # Q
    row << duty_assists # R
    row << duty_deductions # S
    # Deductions should be a negative value ( so we should add instead of subtract these numbers to
    # find the dutiable value - SOW says to subtract)
    row << dutiable_value # T
    row << (duty_rate * 100) # U
    row << duty_deductions.abs # V - Yes, this duplicates column Q..that's what they want
    row << (duty_deductions * duty_rate).round(2).abs # W
    # row << ((invoice_value - dutiable_value) * duty_rate).round(2).abs # W
    row << invoice_line.unit_price # X
    row << invoice_line.quantity # Y

    row
  end

  def lookup_shipment_line shipments, entry, _invoice, invoice_line
    # For LCL shipments, we need to lookup by the Invoice Number
    invoice_number = ocean_lcl_entry?(entry.transport_mode_code, entry.fcl_lcl) ? invoice_number : nil

    container_number = invoice_line.container&.container_number
    line = find_shipment_line(shipments, container_number, invoice_line.po_number, invoice_line.part_number, invoice_line.quantity, invoice_number: invoice_number)

    line
  end

  def in_timezone date
    date.nil? ? nil : date.in_time_zone(timezone)
  end

  def timezone
    "America/New_York"
  end

end; end; end; end
