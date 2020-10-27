module OpenChain; module CustomHandler; module CalendarManager; class CalendarRequester
  def self.run_schedulable opts = {}
    opts = {'emails' => ['bug@vandegriftinc.com'], 'calendars' => []}.merge opts
    emails = opts['emails']
    calendars = opts['calendars']

    empty_calendars = []
    calendars.each do |calendar|
      if new_dates_needed? calendar
        empty_calendars.push calendar
      end
    end

    send_email emails, empty_calendars unless empty_calendars.empty?
  end

  def self.new_dates_needed? calendar_type
     calendar = Calendar.where(calendar_type: calendar_type).where(year: DateTime.now.year).first
     CalendarEvent.where(calendar: calendar).where("event_date > ?", DateTime.now + 1.month).none?
  end

  def self.send_email emails, calendars
    body_text = "The following calendars will run out of values next month:"
    calendars.each { |calendar| body_text += "</br>- #{calendar}" }
    body_text += "</br>Please add new values to the calendar using the upload process in place."

    subject = "VFI Track Calendar Dates are about to run out - Action Required"

    OpenMailer.send_simple_html(emails, subject, body_text.html_safe).deliver_now # rubocop:disable Rails/OutputSafety
  end
end; end; end; end
