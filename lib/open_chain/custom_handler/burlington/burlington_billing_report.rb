require 'open_chain/report/builder_output_report_helper'
require 'open_chain/report/report_email_helper'

module OpenChain; module CustomHandler; module Burlington; class BurlingtonBillingReport
  include OpenChain::Report::BuilderOutputReportHelper
  include OpenChain::Report::ReportEmailHelper

  BurlingtonBillingData ||= Struct.new(:entry_number, :po_numbers, :destination_state, :container_numbers,
                                       :entry_filed_date, :fee_hash, :total_broker_invoice)
  BurlingtonBillingChargeType ||= Struct.new(:charge_code, :charge_description, keyword_init: true)
  CUSTOMS_ENTRY_CHARGE_CODE ||= "0007".freeze

  def self.run_schedulable settings = {}
    self.new.run_report settings
  end

  def run_report settings
    email = parse_email_from_opts(settings)

    workbook = nil
    distribute_reads do
      workbook = generate_report settings['start_date'], settings['end_date']
    end

    file_name_no_suffix = "Burlington_Weekly_Billing_Report_#{ActiveSupport::TimeZone[local_time_zone].now.strftime("%Y%m%d")}"
    write_builder_to_tempfile workbook, file_name_no_suffix do |temp|
      body_msg = "Attached is the Burlington Weekly Billing Report."
      OpenMailer.send_simple_html(email[:to], "Burlington Weekly Billing Report", body_msg, temp, {cc: email[:cc], bcc: email[:bcc]}).deliver_now
    end
  end

  private

    def generate_report start_date_str, end_date_str
      wbk = XlsxBuilder.new
      assign_styles wbk

      # Use start/end date values if they're provided, otherwise default to a week prior to the report run-time,
      # excluding the current day.
      start_date = start_date_str.present? ? Time.zone.parse(start_date_str) : 7.days.ago
      end_date = end_date_str.present? ? Time.zone.parse(end_date_str) : 1.day.ago

      # Note that, although this report gives the visual impression of being entry-based, it is actually broker
      # invoice-based.  It is possible for multiple invoices for the same entry to appear on the report, and ops is
      # cool with this.  (The plan is for them to make some edits by hand before passing it along to Burlington.)
      # In cases where broker invoices for an entry straddle an invoice date window (i.e. one falls within, one is
      # just before), they also want only the broker invoices that are within the invoice date window.  Entry data
      # being split over two weeks' reports is fine.
      # Also note that this data is sorted by entry number.
      brok_invoices = BrokerInvoice.includes(:entry, :broker_invoice_lines)
                                   .where(customer_number: "BURLI", entries: { source_system: "Alliance" })
                                   .where(invoice_date: start_date..end_date)
                                   .merge(Entry.order(:entry_number))

      raw_data = []
      invoice_charge_types = Set.new
      brok_invoices.find_each(batch_size: 250) do |binv|
        raw_data << make_data_obj(binv, invoice_charge_types)
      end

      # Sort the data objects by entry number.  Because of the way PO numbers are exploded out in the report, the
      # user won't be able to sort the results themselves in Excel.  (Known issue, not one we can do anything about.)
      raw_data.sort_by! { |d| [d.entry_number] }

      # Sort the invoice charge types such that CUSTOMS ENTRY is always first, if present (and it probably will be).
      # The rest can be sorted alphabetically.
      invoice_charge_type_array = invoice_charge_types.to_a.sort do |a, b|
        a_desc = a.charge_code == CUSTOMS_ENTRY_CHARGE_CODE ? "0000" : a.charge_description
        b_desc = b.charge_code == CUSTOMS_ENTRY_CHARGE_CODE ? "0000" : b.charge_description
        a_desc <=> b_desc
      end.map(&:charge_description)

      generate_sheet wbk, raw_data, invoice_charge_type_array

      wbk
    end

    def make_data_obj binv, invoice_charge_types
      d = BurlingtonBillingData.new
      # We've already established that these invoices have entries by the query used to get them.  Additionally,
      # although the database technically allows for nil entry ID, that doesn't actually occur in Burlington data.
      d.entry_number = binv.entry.entry_number
      d.po_numbers = binv.entry.po_numbers
      d.destination_state = binv.entry.destination_state
      d.entry_filed_date = binv.entry.entry_filed_date
      d.container_numbers = eat_newlines(binv.entry.container_numbers)
      d.total_broker_invoice = binv.entry.broker_invoice_total

      d.fee_hash = Hash.new { |h, k| h[k] = 0 }
      binv.broker_invoice_lines.each do |bil|
        # These amounts cannot be nil (handled in KewillEntryParser).
        unless exclude_charge? bil
          d.fee_hash[bil.charge_description] += bil.charge_amount
          invoice_charge_types << BurlingtonBillingChargeType.new(charge_code: bil.charge_code, charge_description: bil.charge_description.upcase)
        end
      end
      d
    end

    def eat_newlines str
      str&.gsub("\n ", ",")
    end

    def exclude_charge? bi_line
      ["0001", "0014", "0082", "0099", "0720", "0739"].include? bi_line.charge_code
    end

    def generate_sheet wbk, raw_data, invoice_charge_types
      sheet = wbk.create_sheet "Data"

      wbk.add_body_row sheet, ["Vandegrift Forwarding Company"]
      wbk.add_body_row sheet, ["100 Walnut Avenue"]
      wbk.add_body_row sheet, ["Suite 600"]
      wbk.add_body_row sheet, ["Clark, NJ 07066"]
      wbk.add_body_row sheet, []

      time_zone_now = ActiveSupport::TimeZone[local_time_zone].now
      wbk.add_body_row sheet, ["BURLINGTON MANIFEST DATE: #{time_zone_now.strftime("%m/%d/%Y")}"], styles: [:bold]
      wbk.add_body_row sheet, ["Invoice / Manifest Number: Bur#{time_zone_now.strftime("%Y%m%d")}"], styles: [:bold]
      wbk.add_body_row sheet, []

      # Columns on this report are dynamically determined based on the types of charges that appear in whatever
      # invoices wind up being included on it.
      wbk.add_header_row sheet, ["Entry Number", "PO Numbers", "Destination State", "Entry Filed Date",
                                 "Container Numbers"] + invoice_charge_types + ["Total Broker Invoice"]

      # The bold fonting below follows SOW directions (1933).  Why so many fields per line are bolded was not stated.
      styles = [nil, nil, nil, :date, :bold] + Array.new(invoice_charge_types.length + 1, :bold_currency)
      raw_data.each do |row|
        # Each PO number gets its own line on the report.  Most fields are left blank for second and subsequent POs,
        # including invoice charge-based ones.  Ops will determine which PO is meant to be matched to which charge.
        po_numbers = row.po_numbers&.split("\n ") || [nil]
        po_numbers.each_with_index do |po_number, po_count|
          if po_count == 0
            # Standard line: first PO for the invoice.
            fee_values = []
            invoice_charge_types.each do |charge_type|
              # Not every row will have a charge of every type in it, necessarily.  Default to a zero amount rather
              # than a blank cell if that happens.
              fee_values << (row.fee_hash[charge_type] || BigDecimal(0))
            end

            values = [row.entry_number, po_number, row.destination_state, row.entry_filed_date,
                      row.container_numbers] + fee_values + [row.total_broker_invoice]
          else
            # Additional PO line: most fields are blank.
            values = [nil, po_number, row.destination_state, row.entry_filed_date] +
                     Array.new(invoice_charge_types.length + 2, nil)
          end
          wbk.add_body_row sheet, values, styles: styles
        end
      end

      wbk.set_column_widths sheet, *Array.new(6 + invoice_charge_types.length, 20)

      sheet
    end

    def assign_styles wbk
      wbk.create_style :date, {format_code: "MM/DD/YYYY"}
      wbk.create_style :bold, {b: true}
      wbk.create_style :bold_currency, {format_code: "$#,##0.00", b: true}
    end

    def local_time_zone
      "America/New_York"
    end

end; end; end; end
