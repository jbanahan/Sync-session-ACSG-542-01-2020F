require 'open_chain/kewill_sql_proxy_client'
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

    OpenChain::KewillSqlProxyClient.request_file_tracking_info days_ago, upper_bounds
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
        invoices_to_query[inv] = {broker_reference: ref, invoice_number: inv, invoice_date: format_date_string(row[4].to_s)}
      end
    end

    # split the entries list into groups of 100, then query them and if less than 100 are returned
    # see which ones are missing.
    missing_entries = []
    entries_to_query.keys.each_slice(100) do |list|
      # The last exported from source check is doing an end run around data that might have come over via our new real time feed
      # adding entry data on the fly, which will almost always be there prior to this check.
      # We still want to report the data as missing, since the real time feed only includes dates currently (4/2/2015)
      found = Entry.where(source_system: 'Alliance', broker_reference: list).where("last_exported_from_source IS NOT NULL").pluck :broker_reference
      if found.size < list.size
        list.each do |e|
          missing_entries << entries_to_query[e] if !found.include?(e) && EntryPurge.where(broker_reference: e, source_system: "Alliance").first.nil?
        end
      end
    end

    missing_invoices = []
    invoices_to_query.keys.each_slice(100) do |list|
      # Invoice Numbers appear to have a space after them in the DB sometimes, which throws off our include below
      found = BrokerInvoice.joins(:entry).where(entries: {source_system: 'Alliance'}, invoice_number: list).pluck "trim(broker_invoices.invoice_number)"
      if found.size < list.size
        list.each do |i|
          inv = invoices_to_query[i]
          missing_invoices << inv if !found.include?(i) && EntryPurge.where(broker_reference: inv[:broker_reference], source_system: "Alliance").first.nil?
        end
      end
    end

    if missing_invoices.length > 0 || missing_entries.length > 0
      request_missing_data(missing_entries, missing_invoices)

      wb = XlsMaker.new_workbook

      if missing_entries.length > 0
        add_results wb, "Missing File #s",  ["File #", "File Logged Date", "Invoice Prepared Date"], [:broker_reference, :file_logged_date, :last_billed_date], missing_entries
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

        OpenMailer.send_simple_html("support@vandegriftinc.com", "[VFI Track] Missing Entry Files", message, [t]).deliver_now
      end
    end
  end

  private

    def self.request_missing_data missing_entries, missing_invoices
      requested = Set.new
      Array.wrap(missing_entries).each do |missing_entry|
        ref = missing_entry[:broker_reference]
        next if requested.include? ref
        OpenChain::KewillSqlProxyClient.delay.request_entry_data ref
        requested << ref
      end

      Array.wrap(missing_invoices).each do |missing_invoice|
        ref = missing_invoice[:broker_reference]
        next if requested.include? ref
        OpenChain::KewillSqlProxyClient.delay.request_entry_data missing_invoice[:broker_reference]
        requested << ref
      end
      nil
    end

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