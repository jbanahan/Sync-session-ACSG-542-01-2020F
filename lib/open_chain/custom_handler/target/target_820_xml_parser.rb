require 'rexml/document'
require 'open_chain/custom_handler/nokogiri_xml_helper'
require 'open_chain/integration_client_parser'
require 'open_chain/report/builder_output_report_helper'

# This parser takes a generic XML file (basically EDI converted straight to XML, with EDI segment names applied
# to the XML elements) and generates a report from it.  Each XML generates its own report: there is no
# condensation of multiple XML files happening here.
module OpenChain; module CustomHandler; module Target; class Target820XmlParser
  include OpenChain::CustomHandler::NokogiriXmlHelper
  include OpenChain::IntegrationClientParser
  include OpenChain::Report::BuilderOutputReportHelper

  def self.parse_file data, _log, opts = {}
    self.new.parse(xml_document(data), opts)
  end

  def parse doc, _opts = {}
    wbk = XlsxBuilder.new
    sheet = wbk.create_sheet "Data"

    assign_styles wbk
    styles =  Array.new(5, nil) + [:date, :date, :currency, :currency]

    elem_base = xpath(doc, "FILE/INTERCHANGE/GROUP/TRANSACTION_SET").first

    # A couple of silly header rows followed by three blank rows.
    wbk.add_body_row sheet, ["TGMI"] + Array.new(6, nil), styles: :centered_header, merged_cell_ranges: (0..6)
    wbk.add_body_row sheet, ["Broker ACH Detail Report"] + Array.new(6, nil), styles: :centered_header, merged_cell_ranges: (0..6)
    3.times do
      wbk.add_body_row sheet, []
    end

    # The real header row.
    wbk.add_header_row sheet, ["Payee Name", "Invoice #", "Entry #", "Payment Ref #",
                               "Expense Code", "Invoice Date", "Payment Date", "Payment Amount",
                               "Invoice Amount"]

    # These fields are repeated over all data rows of the file.
    payment_ref_number = first_text(elem_base, "REF[REF01='CK']/REF02")
    payment_date = parse_date(first_text(elem_base, "DTM[DTM01='234']/DTM02"))
    payee_name = first_text(elem_base, "GROUP_1/N1[N101='PE']/N102")

    inbound_file.add_identifier :payment_reference_number, payment_ref_number

    entry_number_cache = Hash.new do |h, k|
      h[k] = Entry.where(broker_reference: k, source_system: Entry::KEWILL_SOURCE_SYSTEM, customer_number: "TARGEN").last&.entry_number
    end

    total_payment_amount = BigDecimal(0)
    xpath(elem_base, "GROUP_2/GROUP_12[RMR/RMR01='IV']") do |elem_iv_rmr_group|
      elem_iv_rmr = xpath(elem_iv_rmr_group, "RMR[RMR01='IV']").first
      invoice_number = et(elem_iv_rmr, "RMR02")
      payment_amount = parse_decimal(et(elem_iv_rmr, "RMR04"))
      invoice_amount = parse_decimal(et(elem_iv_rmr, "RMR05"))
      invoice_date = parse_date(first_text(elem_iv_rmr_group, "DTM[DTM01='003']/DTM02"))

      # The "Invoice Number" sent in this file is actually our entry File Number/Broker Ref.  Using it, we
      # can look up the maching entry.  Caching is used because the same number could appear on multiple
      # file lines.
      entry_number = invoice_number.present? ? entry_number_cache[invoice_number] : nil

      if payment_amount
        total_payment_amount += payment_amount
        values = [payee_name, invoice_number, entry_number, payment_ref_number, "BRO",
                  invoice_date, payment_date, payment_amount, invoice_amount]
        wbk.add_body_row sheet, values, styles: styles
      end
    end

    wbk.add_body_row sheet, []
    wbk.add_body_row sheet, ["Total Payment Amount VANDEGRIFT FORWARDING"] + Array.new(6, nil) + [total_payment_amount],
                     styles: [:centered_header_bold] + Array.new(6, nil) + [:currency_bold], merged_cell_ranges: (0..6)
    wbk.add_body_row sheet, ["Run Date: #{local_time_zone.now.strftime("%m-%d-%Y")}"] + Array.new(6, nil), merged_cell_ranges: (0..6)

    wbk.set_column_widths sheet, *Array.new(9, 20)

    file_name_no_suffix = "Target_820_Report_#{local_time_zone.now.strftime("%Y-%m-%d")}"
    write_builder_to_tempfile wbk, file_name_no_suffix do |temp|
      c = Company.with_customs_management_number("TARGEN").first
      inbound_file.error_and_raise "No importer account exists with 'TARGEN' account number." if c.nil?
      ml = MailingList.where(system_code: "Target 820 Report", company_id: c.id).first
      inbound_file.error_and_raise "No mailing list exists for 'Target 820 Report' system code." if ml.nil?

      body_msg = "Attached is a report based on an 820 receipt from Target."
      OpenMailer.send_simple_html(ml, "Target 820 Report", body_msg, temp).deliver_now
    end

    nil
  end

  private

    def assign_styles wbk
      wbk.create_style(:currency, {format_code: "$#,##0.00"})
      wbk.create_style(:currency_bold, {format_code: "$#,##0.00", b: true})
      wbk.create_style(:date, {format_code: "MM/DD/YYYY"})
      wbk.create_style(:centered_header, {alignment: { horizontal: :center }})
      wbk.create_style(:centered_header_bold, {alignment: { horizontal: :center }, b: true})
    end

    def parse_date str
      str.present? ? Date.strptime(str, '%Y%m%d') : nil
    end

    def parse_decimal str
      str.present? ? BigDecimal(str.strip) : nil
    end

    def local_time_zone
      ActiveSupport::TimeZone["America/New_York"]
    end

end; end; end; end