require "open_chain/report/report_helper"

module OpenChain; module Report; class BouncedEmailReport
  include OpenChain::Report::ReportHelper
  include Rails.application.routes.url_helpers

  def self.run_schedulable config = {}
    email_to = Array.wrap(config['email_to'])

    # If we have mailing lists, we need to make sure to inject them as individual lists, as opposed to an array.
    if config['mailing_list'].present?
      mailing_lists = MailingList.where(system_code: config['mailing_list'])
      mailing_lists.each do |list|
        email_to << list
      end
    end
    raise "At least one email must be present." unless email_to.length > 0

    self.new.run(email_to)
  end

  def run(emails)
    beginning_of_yesterday, end_of_yesterday = get_yesterday_in_timezone("America/New_York")
    bounced_emails = get_bounced_emails_for_dates(beginning_of_yesterday, end_of_yesterday)

    workbook, sheet = create_workbook_and_worksheet

    bounced_emails.each do |email|
      link = sent_email_url(email, host: MasterSetup.get.request_host)
      link_cell = workbook.create_link_cell(link)
      workbook.add_body_row sheet, [link_cell, email.email_to, email.email_subject, email.email_date, email.delivery_error]
    end

    report = xlsx_workbook_to_tempfile(workbook, "Bounced Emails", file_name: "Bounced Emails for #{beginning_of_yesterday.to_date}.xlsx")
    body = "Attached is the bounced email report for #{beginning_of_yesterday.to_date}"
    OpenMailer.send_simple_html(emails, "Bounced Email Report for #{beginning_of_yesterday.to_date}", body, report).deliver!
  end

  def create_workbook_and_worksheet
    wb = XlsxBuilder.new
    sheet1 = wb.create_sheet("Bounced Emails")
    wb.add_body_row sheet1, ['Link', 'To', 'Subject', 'Sent Date', 'Delivery Error'], styles: :default_header
    [wb, sheet1]
  end

  def get_bounced_emails_for_dates(beginning, ending)
    SentEmail.where("email_date >= ? AND email_date <= ?", beginning, ending).where("delivery_error IS NOT NULL OR delivery_error <> ''")
  end

  def get_yesterday_in_timezone(timezone)
    yesterday = ActiveSupport::TimeZone[timezone].now().yesterday
    beginning_of_yesterday = yesterday.beginning_of_day
    end_of_yesterday = yesterday.end_of_day

    [beginning_of_yesterday.in_time_zone('UTC'), end_of_yesterday.in_time_zone('UTC')]
  end
end; end; end