require 'open_chain/sql_proxy_client'
require 'open_chain/schedule_support'

module OpenChain; module Report; class AllianceWebtrackingMonitorReport
  include OpenChain::ScheduleSupport

  def self.run_schedulable opts = {}
    opts = {'days_ago' => 7}.merge opts

    now = Time.zone.now.in_time_zone("Eastern Time (US & Canada)")

    days_ago = (now - opts['days_ago'].to_i.days).to_date
    # This is just so we don't say files are missing that were filed or invoiced less than an hour
    # ago.  Give them a little bit of time to come over.
    upper_bounds = now - 1.hour

    OpenChain::SqlProxyClient.request_file_tracking_info days_ago, upper_bounds
  end

  def self.process_alliance_query_details json_results
    # The results are a union of two queries.  One which lists all entry files logged in last X days
    # The other is all invoices file in last X days.  The first query is just a file number
    # with blank data in column 2 and the other is the invoice numbers in column 2 blank data in 1

    entries_to_query = {}
    invoices_to_query = {}

    results = JSON.parse json_results
    results.each do |row|
      # The to_s is there to force the invoice/file # to be a string, since the rails json transfer has a tendency to 
      # change it to an int
      ref = row[0].to_s
      if !ref.blank?
        entries_to_query[ref] = {broker_reference: ref, file_logged_date: format_date_string(row[2].to_s), last_billed_date: format_date_string(row[3].to_s)}
      end

      inv = row[1].to_s
      if !inv.blank?
        invoices_to_query[inv] = {invoice_number: inv, invoice_date: format_date_string(row[4].to_s)}
      end
    end

    # split the entries list into groups of 100, then query them and if less than 100 are returned
    # see which ones are missing.
    missing_entries = []
    entries_to_query.keys.each_slice(100) do |list|
      found = Entry.where(source_system: 'Alliance', broker_reference: list).pluck :broker_reference
      if found.size < list.size
        list.each do |e|
          missing_entries << entries_to_query[e] if !found.include?(e)
        end
      end
    end

    missing_invoices = []
    invoices_to_query.keys.each_slice(100) do |list|
      # Invoice Numbers appear to have a space after them in the DB sometimes, which throws off our include below
      found = BrokerInvoice.joins(:entry).where(entries: {source_system: 'Alliance'}, invoice_number: list).pluck "trim(broker_invoices.invoice_number)"
      if found.size < list.size
        list.each do |i|
          missing_invoices << invoices_to_query[i] if !found.include?(i)
        end
      end
    end

    if missing_invoices.length > 0 || missing_entries.length > 0
      wb = XlsMaker.new_workbook

      if missing_entries.length > 0
        add_results wb, "Missing File #s",  ["File #", "File Logged Date", "Last Billed Date"], [:broker_reference, :file_logged_date, :last_billed_date], missing_entries
      end

      if missing_invoices.length > 0
        add_results wb, "Missing Invoice #s", ["Invoice #", "Invoice Date"], [:invoice_number, :invoice_date], missing_invoices
      end

      Tempfile.open(["Missing Entry Files ", ".xls"]) do |t|
        wb.write t
        t.rewind
        message = "Attached is a listing of "
        if missing_entries.length > 0
          message += "#{missing_entries.length} #{"Entry".pluralize(missing_entries.length)}"
          message += " and " if missing_invoices.length > 0
        end

        if missing_invoices.length > 0
          message += "#{missing_invoices.length} #{"Invoice".pluralize(missing_invoices.length)}"
        end

        message += " missing from VFI Track. Please ensure these files get pushed from Alliance to VFI Track."

        OpenMailer.send_simple_html("support@vandegriftinc.com", "[VFI Track] Missing Entry Files", message, [t]).deliver!
      end
    end
  end

  private

    def self.add_results wb, sheet_name, headers, columns, results
      sheet = XlsMaker.create_sheet wb, sheet_name, headers
      column_widths = []
      counter = 0
      results.each do |r|
        XlsMaker.add_body_row sheet, (counter+=1), columns.map {|c| r[c]}, column_widths
      end
      sheet
    end
    private_class_method :add_results

    def self.format_date_string val
      out = ""
      if !val.blank? && val.length >= 8
        out = val[0, 4] + "-" + val[4, 2] + "-" + val[6, 2]
      end
      out
    end
end; end; end