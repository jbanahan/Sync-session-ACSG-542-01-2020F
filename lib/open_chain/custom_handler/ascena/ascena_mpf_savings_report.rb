require 'open_chain/report/report_helper'
require 'open_chain/fiscal_calendar_scheduling_support'
module OpenChain; module CustomHandler; module Ascena; class AscenaMpfSavingsReport
  include OpenChain::Report::ReportHelper
  extend OpenChain::FiscalCalendarSchedulingSupport

  attr_accessor :cust_numbers

  ANN_CUST_NUM = "ATAYLOR"
  ASCENA_CUST_NUM = "ASCE"

  def self.permission? user
    imp_ascena = ascena
    imp_ann = ann
    return false unless ascena && ann
    ms = MasterSetup.get
    ms.custom_feature?("Ascena Reports") &&
        user.view_entries? &&
        (user.company.master? || imp_ascena.can_view?(user) || imp_ann.can_view?(user))
  end

  def self.ascena
    Company.importers.with_customs_management_number(ASCENA_CUST_NUM).first
  end

  def self.ann
    Company.importers.with_customs_management_number(ANN_CUST_NUM).first
  end

  def self.fiscal_month settings
    if settings['fiscal_month'].to_s =~ /(\d{4})-(\d{2})/
      year = $1
      month = $2
      FiscalMonth.where(company_id: ascena.id, year: year.to_i, month_number: month.to_i).first
    else
      nil
    end
  end

  def self.run_report run_by, settings = {}
    fm = fiscal_month settings

    raise "No fiscal month configured for Ascena." unless fm

    self.new(settings['cust_numbers']).run fm
  end

  def self.run_schedulable config = {}
    email_to = Array.wrap(config['email'])
    raise "At least one email must be present." unless email_to.length > 0

    run_if_configured(config) do |fiscal_month, fiscal_date|
      fm = fiscal_month.back(1)
      self.new(config['custom_numbers']).run(fm) do |report|
        body = "Attached is the MPF Savings Report for #{fm.fiscal_descriptor}."
        OpenMailer.send_simple_html(email_to, "MPF Savings Report #{fm.fiscal_descriptor}", body, report).deliver_now
      end
    end
  end

  def mpf_calculation_date(entry)
    entry.first_it_date || entry.release_date
  end

  def max_mpf_amount(entry)
    entry_date = mpf_calculation_date(entry)

    if entry_date.present? && entry_date < Date.parse("01/10/2018")
      BigDecimal.new("497.99")
    elsif entry_date.present? && entry_date < Date.parse("01-10-2019")
      BigDecimal("508.70")
    else
      BigDecimal.new("519.76")
    end
  end

  def min_mpf_amount(entry)
    entry_date = mpf_calculation_date(entry)
    if entry_date.present? && entry_date < Date.parse("01-10-2018")
      BigDecimal.new("25.67")
    elsif entry_date.present? && entry_date < Date.parse("01-10-2019")
      BigDecimal.new("26.22")
    else
      BigDecimal.new("26.79")
    end
  end

  def initialize cust_numbers
    @cust_numbers = Array.wrap(cust_numbers).sort
  end

  def run fiscal_month
    wb, total_sheet, data_sheet = create_workbook
    generate_worksheet_headers(wb, total_sheet, data_sheet)

    savings_master_total_hash = Hash.new(0)
    raw_data_array = []

    entries = Entry.where(customer_number: @cust_numbers).
        where("master_bills_of_lading IS NOT NULL AND master_bills_of_lading <> ''").
        where("entries.fiscal_date >= ? AND entries.fiscal_date < ?", fiscal_month.start_date, fiscal_month.end_date).
        where(transport_mode_code: ['10', '11', '40', '41'])
    entries.each do |entry|
      savings_hash = generate_initial_hash(entry)
      gather_invoice_data(entry, savings_hash, raw_data_array)
      calculate_entry_totals(savings_hash, entry)
      write_to_totals_sheet(savings_hash, total_sheet, wb)
      calculate_grand_totals(savings_hash[:totals], savings_master_total_hash)
    end
    write_raw_data(raw_data_array, data_sheet, wb)
    write_grand_totals_row(savings_master_total_hash, total_sheet, wb)

    if block_given?
      xlsx_workbook_to_tempfile(wb, "MPFSavings", file_name: "MPF Savings Report #{fiscal_month.fiscal_descriptor}.xlsx") do |f|
        yield f
      end
    else
      xlsx_workbook_to_tempfile(wb, "MPFSavings", file_name: "MPF Savings Report #{fiscal_month.fiscal_descriptor}.xlsx")
    end
  end

  def write_grand_totals_row(hsh, sheet, wb)
    ascena_footer = wb.create_style(:ascena_footer, {fg_color: 'ffffff', bg_color: '2121c9', b: true, format_code: "#,##0.00"}, prevent_override: false, return_existing: true)
    wb.add_body_row sheet, ["Grand Total", "", "", "", "", "", hsh[:sum_payable], hsh[:sum_mpf], hsh[:original_per_bl], hsh[:savings]], styles: ascena_footer
  end

  def calculate_grand_totals(totals, hsh)
    hsh[:sum_payable] += totals[:sum_payable]
    hsh[:sum_mpf] += totals[:sum_mpf]
    hsh[:original_per_bl] += totals[:original_per_bl]
    hsh[:savings] += totals[:savings]
  end

  def write_raw_data(raw_data_array, data_sheet, workbook)
    raw_data_array.each do |line|
      workbook.add_body_row data_sheet, line
    end
  end

  def write_to_totals_sheet(savings_hash, total_sheet, workbook)
    return if savings_hash[:master_bill_list].blank?
    write_entry_header(savings_hash, total_sheet, workbook)
    write_remaining_entry_rows(savings_hash, total_sheet, workbook) if savings_hash[:master_bill_list].length > 0
    write_totals_row(savings_hash, total_sheet, workbook)
  end

  def write_entry_header(hsh, sheet, workbook)
    mbill_data = hsh[:master_bill_list].shift
    mbill_number = mbill_data.shift
    mbill_data = mbill_data[0]

    workbook.add_body_row sheet, [hsh[:transport], hsh[:entry_port_name], hsh[:broker_number], hsh[:entry_number],
                                  hsh[:total_master_bills], mbill_number, mbill_data[:sum_payable],
                                  mbill_data[:sum_mpf], mbill_data[:original_per_bl]], styles: [nil, nil, nil, nil, nil, nil, :default_currency, :default_currency, :default_currency, :default_currency]
  end

  def write_remaining_entry_rows(hsh, sheet, workbook)
    hsh[:master_bill_list].each do |key, value|
      workbook.add_body_row sheet, ["", "", "", "", "", key, value[:sum_payable], value[:sum_mpf],
                                    value[:original_per_bl]], styles: [nil, nil, nil, nil, nil, nil, :default_currency, :default_currency, :default_currency, :default_currency]
    end
  end

  def write_totals_row(hsh, sheet, workbook)
    ascena_total_row = workbook.create_style(:ascena_total_row, {fg_color: "000000", bg_color: "c6d9f0", b: true, format_code: "#,##0.00"}, prevent_override: false, return_existing: true)
    workbook.add_body_row sheet, ["", "", "", "#{hsh[:entry_number]} Total", "", "", hsh[:totals][:sum_payable], hsh[:totals][:sum_mpf], hsh[:totals][:original_per_bl], hsh[:totals][:savings]],
                          styles: [ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row, ascena_total_row]
  end

  def generate_initial_hash(entry)
    hsh = {}
    hsh[:transport] = entry.transport_mode_code
    hsh[:entry_port_name] = entry.us_entry_port.try(:name)
    hsh[:broker_number] = entry.broker_reference
    hsh[:entry_number] = entry.entry_number
    hsh[:master_bills] = entry.split_master_bills_of_lading
    hsh[:total_master_bills] = hsh[:master_bills].count
    hsh[:master_bill_list] = {}
    hsh[:totals] = {}
    hsh
  end

  def invoice_master_bills_of_lading(entry, invoice)
    if ['10', '11'].include? entry.transport_mode_code
      invoice.master_bills_of_lading
    else
      invoice.house_bills_of_lading
    end
  end

  def gather_invoice_data(entry, savings_hash, raw_data_array)
    max_original_per_bl = max_mpf_amount(entry)

    entry.commercial_invoices.each do |ci|
      invoice_lines = ci.commercial_invoice_lines.all
      dump_raw_data(entry, ci, invoice_lines, raw_data_array)
      master_bill = invoice_master_bills_of_lading(entry, ci)
      if ci.master_bills_of_lading.present? || ci.house_bills_of_lading.present?
        invoice_lines.each do |line|
          hsh = (savings_hash[:master_bill_list][master_bill] ||= Hash.new(0))
          hsh[:sum_payable] += (line.prorated_mpf.presence || BigDecimal("0"))
          hsh[:sum_mpf] += (line.mpf || BigDecimal("0"))
          hsh[:original_per_bl] = hsh[:sum_mpf] > max_original_per_bl ? max_original_per_bl : hsh[:sum_mpf]
        end
        if savings_hash[:master_bill_list][master_bill][:sum_payable] == 0 && savings_hash[:master_bill_list][master_bill][:sum_mpf] == 0
          savings_hash[:master_bill_list].delete(master_bill)
        end
      end
    end
  end

  def dump_raw_data(entry, invoice, lines, raw_array)
    brn = "CL2"
    importer_code = entry.customer_number
    customer_name = entry.customer_name
    importer_tax_id = entry.importer_tax_id
    broker_ref_number = entry.broker_reference
    entry_number = entry.entry_number
    entry_type = entry.entry_type
    export_country_codes = entry.export_country_codes
    origin_country_codes = entry.origin_country_codes
    export_date = entry.export_date
    port_of_lading = entry.lading_port_code
    port_of_unlading = entry.unlading_port_code
    port_of_entry = entry.entry_port_code
    import_date = entry.import_date
    arrival_date = entry.arrival_date
    mode_of_transport = entry.transport_mode_code
    vessel = entry.vessel
    voyage_flight = entry.voyage
    container_numbers = entry.container_numbers.to_s.split("\n").count
    first_release_date = entry.first_release_date
    release_date = entry.release_date
    master_bills_of_lading_count = entry.split_master_bills_of_lading.count
    joined_master_bills_of_lading = entry.split_master_bills_of_lading.join(', ')
    invoice_number = invoice.invoice_number
    invoice_mid = invoice.mfid

    lines.each do |line|
      raw_array << [brn, importer_code, customer_name, importer_tax_id, broker_ref_number, entry_number, entry_type,
                    export_country_codes, origin_country_codes, export_date, port_of_lading, port_of_unlading, port_of_entry,
                    import_date, arrival_date, mode_of_transport, vessel, voyage_flight, container_numbers, '', '', '', '', '',
                    first_release_date, release_date, line.po_number, invoice_master_bills_of_lading(entry, invoice),
                    master_bills_of_lading_count, joined_master_bills_of_lading, invoice_number, invoice_mid,
                    line.customs_line_number, line.value, line.total_duty, line.prorated_mpf, line.mpf, line.quantity, line.unit_of_measure]
    end
  end

  def minimum_mpf_calculation(totals, entry)
    sum_mpf = min_mpf_amount(entry)
    totals[:sum_payable] = if totals[:sum_payable] > 0 && totals[:sum_payable] <= sum_mpf
                             sum_mpf
                           else
                             totals[:sum_payable]
                           end

    totals[:original_per_bl] = if totals[:sum_mpf] > 0 && totals[:sum_mpf] <= sum_mpf
                                 sum_mpf
                               else
                                 totals[:original_per_bl]
                               end
  end

  def calculate_entry_totals(savings_hash, entry)
    savings_hash[:totals][:sum_payable] = savings_hash[:master_bill_list].values.inject(0) {|sum, mb| sum + mb[:sum_payable]}
    savings_hash[:totals][:sum_mpf] = savings_hash[:master_bill_list].values.inject(0) {|sum, mb| sum + mb[:sum_mpf]}
    savings_hash[:totals][:original_per_bl] = savings_hash[:master_bill_list].values.inject(0) {|sum, mb| sum + mb[:original_per_bl]}
    minimum_mpf_calculation(savings_hash[:totals], entry)
    savings_hash[:totals][:savings] = savings_hash[:totals][:original_per_bl] - savings_hash[:totals][:sum_payable]
  end

  def create_workbook
    wb = XlsxBuilder.new
    sheet1 = wb.create_sheet("Savings Worksheet")
    sheet2 = wb.create_sheet("Raw data results")
    [wb, sheet1, sheet2]
  end

  def generate_worksheet_headers(wb, totals, data)
    ascena_header = wb.create_style(:ascena_header, {fg_color: 'ffffff', bg_color: '2121c9'}, return_existing: true)
    wb.add_body_row totals, ["", "", "", "", "", "", "Values", "", "Original Per B/L", "MPF"], styles: ascena_header
    wb.add_body_row totals, ["Trans", "Entry Port Description", "Job Number", "Entry No.", "Mbill Count",
                             "Carrier B/L Number", "Sum of Payable MPF", "Sum of MPF", "Sum of MPF", "Savings"], styles: ascena_header
    wb.add_body_row data, ["Brn", "Importer Code", "Importer", "Importer No.", "Job Number", "Entry No.",
                           "Entry Type", "C/E Name", "C/O Name", "Export Date", "Lading Port Desc", "Arrival Port Desc",
                           "Entry Port Desc", "Import Date", "Arrival Date", "Trans", "Vessel", "Voyage Flight",
                           "Containers Count", "Intensive Date", "Customs Hold Date", "Agriculture Hold Date",
                           "FDA Hold Date", "FDA Release Date", "First Release Date", "Release Date",
                           "P.O. Number", "Carrier B/L Number", "Mbill Count", "Master Bills", "Invoice Number",
                           "Manufacturer Code", "7501 Line Number", "Line Entered Value", "Duty", "Payable MPF",
                           "MPF", "Invoice Quantity", "Invoice UQ"]
  end
end; end; end; end
