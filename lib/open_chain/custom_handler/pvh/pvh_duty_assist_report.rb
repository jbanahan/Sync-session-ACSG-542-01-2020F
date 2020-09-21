require 'open_chain/fiscal_calendar_scheduling_support'
require 'open_chain/custom_handler/pvh/pvh_entry_shipment_matching_support'
require 'open_chain/custom_handler/pvh/pvh_fiscal_calendar_scheduling_support'
require 'open_chain/report/report_helper'

# PVH refers to this as the "Data Dump" report.
module OpenChain; module CustomHandler; module Pvh; class PvhDutyAssistReport
  include OpenChain::CustomHandler::Pvh::PvhEntryShipmentMatchingSupport
  include OpenChain::CustomHandler::Pvh::PvhFiscalCalendarSchedulingSupport
  include OpenChain::Report::ReportHelper
  extend OpenChain::FiscalCalendarSchedulingSupport

  PVH_DUTY_DISCOUNT_REPORT_USERS ||= 'pvh_duty_discount_report'.freeze

  def self.permission?(user)
    user.view_entries? && MasterSetup.get.custom_feature?("WWW VFI Track Reports") &&
      (user.company.master? || user.in_group?(Group.use_system_group(PVH_DUTY_DISCOUNT_REPORT_USERS, name: "PVH Duty Discount Report",
                                                                                                     description: "Users able to run the PVH Duty Discount Report.")))
  end

  def self.run_report _run_by, settings
    self.new.run_data_dump_report settings
  end

  def self.run_schedulable config = {}
    config['email'] = Array.wrap(config['email'])
    raise "Scheduled instances of the PVH / PVH Canada Duty Assist Report must include an email setting with at least one email address." unless config['email'].length > 0
    run_if_configured(config) do |fiscal_month, _fiscal_date|
      self.new.run_data_dump_report config, current_fiscal_month: fiscal_month
    end
  end

  def run_data_dump_report settings, current_fiscal_month: nil
    customer_number = settings['company']
    raise "No customer number provided." if customer_number.blank?

    scheduling_type = self.class.scheduling_type settings
    fiscal_date_start, fiscal_date_end, fiscal_month, fiscal_year = get_fiscal_period_dates(settings['fiscal_month'],
                                                                                            current_fiscal_month, scheduling_type, customer_number)

    workbook = nil
    distribute_reads do
      workbook = generate_report(fiscal_date_start, fiscal_date_end, customer_number)
    end

    fiscal_descriptor = filename_fiscal_descriptor(fiscal_year, fiscal_month, scheduling_type)
    file_name = "#{customer_number}_Data_Dump_#{fiscal_descriptor}_#{ActiveSupport::TimeZone[time_zone].now.strftime("%Y-%m-%d")}.xlsx"
    if settings['email'].present?
      workbook_to_tempfile workbook, "Duty Assist", file_name: file_name do |temp|
        date_label = customer_number == "PVH" ? "ACH Due Date" : "CADEX Acceptance Date"
        body_msg = "Attached is the \"#{customer_number} Data Dump Report, #{fiscal_year}-#{fiscal_month}\" based on #{date_label}."
        OpenMailer.send_simple_html(settings['email'], "#{customer_number} Data Dump", body_msg, temp).deliver_now
      end
    else
      workbook_to_tempfile(workbook, "Duty Assist", file_name: file_name.to_s)
    end
  end

  private

    def generate_report fiscal_date_start, fiscal_date_end, customer_number
      entry_ids = entries(fiscal_date_start, fiscal_date_end, customer_number)

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

    def entries fiscal_date_start, fiscal_date_end, customer_number
      Entry.where(customer_number: customer_number, fiscal_date: fiscal_date_start..fiscal_date_end).order(:release_date).pluck(:id)
    end

    def preload_entry entry
      ActiveRecord::Associations::Preloader.new.preload(entry, [:broker_invoices,
                                                                {commercial_invoices: {commercial_invoice_lines: [:commercial_invoice_tariffs, :container]}}])
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
      date.nil? ? nil : date.in_time_zone(time_zone)
    end

end; end; end; end
