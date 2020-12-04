require 'open_chain/report/builder_output_report_helper'

# Target calls this the CSR.  It's a daily report that shows entries that have been delayed
# by US Customs for any reason.
module OpenChain; module CustomHandler; module Target; class TargetCustomsStatusReport
  include OpenChain::Report::BuilderOutputReportHelper

  def self.run_schedulable settings = {}
    self.new.run_customs_status_report settings
  end

  def run_customs_status_report settings
    raise "Email address is required." if settings['email'].blank?

    workbook = nil
    distribute_reads do
      workbook = generate_report
    end

    file_name_no_suffix = "Target_Customs_Status_Report_#{ActiveSupport::TimeZone[local_time_zone].now.strftime("%Y-%m-%d")}"
    write_builder_to_tempfile workbook, file_name_no_suffix do |temp|
      body_msg = "Attached is the Customs Status Report."
      OpenMailer.send_simple_html(settings['email'], "Target Customs Status Report", body_msg, temp).deliver_now
    end
  end

  def generate_report
    wbk = XlsxBuilder.new
    assign_styles wbk

    raw_data = []
    entries.find_each(batch_size: 100) do |ent|
      entry_rows = []
      # Unresolved exceptions are meant to appear on the report regardless of the entry's One USG Date status.
      # These need to be resolved by ops.  Exceptions drop off as soon as they are resolved.
      ent.entry_exceptions.each do |exc|
        if !exc.resolved?
          entry_rows += make_data_objects(ent, convert_reason_code(exc.code), exc.comments)
        end
      end

      # Target wants to see "in progress" entries on this report even if they don't have exceptions.
      if entry_rows.length == 0 && include_entry?(ent)
        entry_rows += make_data_objects(ent, nil, nil)
      end

      # Each set of entry rows in the report should be ordered by reason code.
      raw_data += entry_rows.sort_by(&:reason_code)
    end

    generate_sheet wbk, raw_data

    wbk
  end

  # Looks for entries that either have an exception that has not been resolved, or that have not been
  # closed out (as determined by the presence of One USG Date).  Excludes "shell entries", which have blank
  # values for most fields.  We're ruling out shell by excluding entries that have no departments or PO numbers.
  def entries
    Entry.includes(:entry_exceptions, :containers, :entry_comments,
                   {commercial_invoices: :commercial_invoice_lines},
                   {bill_of_ladings: :containers})
         .where(customer_number: "TARGEN", source_system: "Alliance")
         .where("(one_usg_date IS NULL OR first_release_date IS NULL OR
                 (SELECT COUNT(*) FROM entry_exceptions AS exc WHERE exc.entry_id = entries.id AND exc.resolved_date IS NULL) > 0)")
         .where("((departments IS NOT NULL AND departments != '') OR (po_numbers IS NOT NULL AND po_numbers != ''))")
  end

  def convert_reason_code code
    case code
    # CRT-to-TGT interpretation may not be necessary, but it doesn't hurt.
    when "CRH"
        "TGT"
    # FW was used because CM will not permit an ampersand in the exception code field.
    when "FW"
        "F&W"
    else
        code
    end
  end

  def include_entry? ent
    # Entries that involve the FDA or EPA are handled a little differently than others.
    if ent.includes_pga_summary_for_agency?("FDA", claimed_pga_lines_only: true)
      ent.one_usg_date.nil? && !ent.fda_message.to_s.upcase.include?("MAY PROCEED")
    elsif ent.includes_pga_summary_for_agency?("EPA", claimed_pga_lines_only: true)
      ent.one_usg_date.nil? && !ent.matching_entry_comments?(/^EPA .*MAY PROCEED/i, username: "CUSTOMS")
    else
      ent.first_release_date.nil?
    end
  end

  private

  def make_data_objects entry, exception_code, comments
    entry.commercial_invoices.map { |invoice| CsrReportDataFactory.make(entry, invoice, exception_code, comments) }
  end

  def generate_sheet wbk, raw_data
    sheet = wbk.create_sheet "Exceptions", headers: ["Importer", "Broker", "File No.", "Dept", "P.O.", "Doc Rec'd Date", "ETA", "ABI Date",
                                                     "Reason Code", "Comments from Broker", "No of Cntrs", "Port of Lading", "Port of Unlading",
                                                     "Vessel", "Bill of Lading Number", "Containers", "Consolidated Entry"]

    raw_data.each do |row|
      styles = [nil, nil, nil, nil, nil, :date, :date, :date, nil, nil, :integer, nil, nil, nil, nil, nil, nil]
      values = [row.importer, row.broker, row.file_number, row.departments, row.po_number, row.docs_received_date,
                row.eta_date, row.abi_date, row.reason_code, row.broker_comments, row.container_count, row.port_of_lading,
                row.port_of_unlading, row.vessel, row.bill_of_lading_number, row.containers, row.consolidated]
      wbk.add_body_row sheet, values, styles: styles
    end

    wbk.set_column_widths sheet, *Array.new(16, 20)

    sheet
  end

  def assign_styles wbk
    wbk.create_style :integer, {format_code: "#,##0"}
    wbk.create_style :date, {format_code: "MM/DD/YYYY"}
  end

  def local_time_zone
    "America/New_York"
  end

  class CsrReportDataFactory
    CsrReportData ||= Struct.new(:importer, :broker, :file_number, :departments, :po_number,
                                 :docs_received_date, :eta_date, :abi_date, :reason_code,
                                 :broker_comments, :container_count, :port_of_lading,
                                 :port_of_unlading, :vessel, :bill_of_lading_number,
                                 :containers, :consolidated)

    def self.make entry, invoice, exception_code, comments
      ctrs = containers(entry, invoice.invoice_number)
      d = CsrReportData.new

      d.importer = "TGMI"
      d.broker = "316"
      d.file_number = entry.broker_reference
      d.departments = departments(invoice)
      d.po_number = po_number(invoice)
      d.docs_received_date = entry.docs_received_date
      d.eta_date = entry.import_date
      d.abi_date = entry.entry_filed_date
      d.reason_code = exception_code
      d.broker_comments = comments
      d.container_count = ctrs.length if ctrs
      d.port_of_lading = entry.lading_port_code
      d.port_of_unlading = entry.unlading_port_code
      d.vessel = entry.vessel
      d.bill_of_lading_number = invoice.invoice_number
      d.containers = ctrs.map(&:container_number).join(", ") if ctrs
      d.consolidated = consolidated?(entry) ? "Y" : nil

      d
    end

    # Invoice number always matches BOL number
    def self.containers entry, inv_number
      entry.bill_of_ladings.find { |bol| bol.bill_type == "master" && bol.bill_number == inv_number }&.containers
    end

    def self.departments invoice
      invoice.commercial_invoice_lines.map(&:department).uniq.join(", ")
    end

    # Every line will always share the same PO number, but gather them all in case there's a keying error.
    def self.po_number invoice
      invoice.commercial_invoice_lines.map(&:po_number).uniq.join(", ")
    end

    # Invoices always have a 1:1 correspondence with their BOLs
    def self.consolidated? entry
      entry.commercial_invoices.length > 1
    end
  end

end; end; end; end
