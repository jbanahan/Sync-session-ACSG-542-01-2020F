require 'open_chain/custom_handler/intacct/intacct_daily_statement_payer'

module OpenChain; module CustomHandler; module Intacct; class IntacctStatementProcessor

  def self.run_schedulable opts
    instance = self.new

    raise "At least one email recipient must be configured." if opts["email_to"].blank?

    start_date = parse_start_date opts
    send_blank_reports = (opts["send_blank_reports"].presence || "false").to_s.to_boolean

    if opts["monthly"]
      instance.run_monthly_statements opts["email_to"], start_date: start_date, send_blank_reports: send_blank_reports
    elsif opts["daily"]
      instance.run_daily_statements opts["email_to"], start_date: start_date, send_blank_reports: send_blank_reports
    else
      raise "A 'daily' or 'monthly' configuration value must be present."
    end
  end

  def self.parse_start_date opts
    d = opts["start_date"]

    # If start date isn't set up, we don't care
    if d
      date = Time.zone.parse(d)
      raise "Invalid 'start_date' value of '#{d}'." if date.nil?

      return date.to_date
    else
      nil
    end
    return nil if d.nil?
  end

  def initialize statement_payer: OpenChain::CustomHandler::Intacct::IntacctDailyStatementPayer.new
    @payer = statement_payer
  end

  def discover_statements pay_type, start_date
    # Exclude everything that has been synced already
    query = DailyStatement.joins(DailyStatement.need_sync_join_clause('Intacct')).
      # include the daily statement entries because the payer will need these
      includes(:daily_statement_entries).
      where(DailyStatement.has_never_been_synced_where_clause()).
      where(pay_type: pay_type, status: "F").
      where("daily_statements.final_received_date IS NOT NULL")

    if start_date
      query = query.where("daily_statements.final_received_date >= ?", start_date)
    end

    if pay_type == 6
      query = query.includes([:monthly_statement]).
                joins(:monthly_statement).
                where(monthly_statements: {status: "F"}).
                order("monthly_statements.statement_number ASC, daily_statements.final_received_date ASC, daily_statements.statement_number ASC")

    else
      query = query.order("daily_statements.final_received_date ASC, daily_statements.statement_number ASC")
    end

    query
  end

  def pay_statements statements
    paid_statements = []
    errored_statements = []

    statements.each do |daily_statement|
      Lock.db_lock(daily_statement) do
        errors = nil
        begin
          # We may be getting daily statements that have nothing owed...just skip them here (there shouldn't be
          # any record in Intacct for these) and allow the sync record to write out for them.
          if daily_statement.total_amount.to_f > 0
            errors = @payer.pay_statement daily_statement

            if errors.blank?
              paid_statements << daily_statement
            else
              errored_statements << {errors: errors, statement: daily_statement}
            end
          end
        ensure
          # Mark the statement as synced - regardless of if there are errors...If there are errors, it means the statement
          # will have to be done manually (if there's systemic errors - [Intacct is down, etc], then we can clear the
          # sync record's sent_at and have the system re-run)
          sr = daily_statement.sync_records.where(trading_partner: "Intacct").first_or_initialize
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (Time.zone.now + 1.minute)
          if errors.blank?
            sr.failure_message = nil
          else
            sr.failure_message = Array.wrap(errors).join("\n ")
          end

          sr.save!
        end
      end
    end

    {paid_statements: paid_statements, errored_statements: errored_statements}
  end

  def find_and_pay_daily_statements start_date
    # 2 is the pay type for Broker Daily Statements
    pay_statements(discover_statements(2, start_date))
  end

  def find_and_pay_monthly_statements start_date
    # 6 is the pay type for Broker Monthly Statements
    # Monthly statements consist of a bunch of daily statements grouped together
    pay_statements(discover_statements(6, start_date))
  end

  def run_daily_statements email_to, start_date: nil, send_blank_reports: false
    results = find_and_pay_daily_statements start_date
    send_report(email_to, results, false)if send_blank_reports || !blank_results?(results)
  end

  def run_monthly_statements email_to, start_date: nil, send_blank_reports: false
    results = find_and_pay_monthly_statements start_date
    send_report(email_to, results, true) if send_blank_reports || !blank_results?(results)
  end

  def send_report email_to, results, monthly
    workbook = generate_report(results, monthly)

    errors = has_pay_errors?(results)

    subject = "#{monthly ? "Monthly" : "Daily"} Statements Paid #{Time.zone.now.to_date}"
    filename = "#{subject.gsub(" ", "_")}.xls"

    subject += " With Errors" if errors

    body = "<p>#{monthly ? "Monthly" : "Daily"} Statements have been paid in Intacct.</p>"
    if errors
      body += "<p>Not all statements could be automatically paid. All statements listed on the 'Statement Errors' tab of the attached report must be paid manually.</p>"
    end

    body += "<p>For a full listing of all statements paid see the 'Paid Statements' tab on the attached report.</p>"

    Tempfile.open(["intacct_statements", ".xls"]) do |file|
      file.binmode
      workbook.write file
      Attachment.add_original_filename_method(file, filename)
      file.rewind

      OpenMailer.send_simple_html(email_to, subject, body.html_safe, file).deliver_now
    end
  end


  def generate_report pay_results, monthly
    workbook = XlsMaker.new_workbook

    if has_pay_errors?(pay_results)
      errors = XlsMaker.create_sheet(workbook, "Statement Errors")
      write_errors_sheet(errors, pay_results[:errored_statements], monthly)
    end

    paid = XlsMaker.create_sheet workbook, "Paid Statements"
    write_results_sheet paid, pay_results[:paid_statements], monthly

    workbook
  end

  def write_errors_sheet sheet, errored_statement_data, monthly
    headers = ["Daily Statement #", "Total Amount", "Final Statement Date", "Port Code", "Errors"]
    headers.unshift("Monthly Statement #") if monthly
    widths = []
    XlsMaker.add_header_row sheet, 0, headers, widths

    row_num = 0
    errored_statement_data.each do |err|
      row = []
      statement = err[:statement]
      row << statement.monthly_statement.try(:statement_number) if monthly
      row.push *[statement.statement_number, statement.total_amount, statement.final_received_date, statement.port_code, err[:errors].join("\n ")]
      XlsMaker.add_body_row(sheet, (row_num += 1), row, widths)
    end
    nil
  end

  def write_results_sheet sheet, statements, monthly
    headers = ["Daily Statement #", "Total Amount", "Final Statement Date", "Port Code"]
    headers.unshift("Monthly Statement #") if monthly
    widths = []
    XlsMaker.add_header_row sheet, 0, headers, widths

    row_num = 0
    statements.each do |statement|
      row = []
      row << statement.monthly_statement.try(:statement_number) if monthly
      row.push *[statement.statement_number, statement.total_amount, statement.final_received_date, statement.port_code]
      XlsMaker.add_body_row(sheet, (row_num += 1), row, widths)
    end
    nil
  end

  def has_pay_errors? results
    errors = Array.wrap(results[:errored_statements]).length > 0
  end

  def blank_results? results
    Array.wrap(results[:errored_statements]).length == 0 && Array.wrap(results[:paid_statements]).length == 0
  end

end; end; end; end