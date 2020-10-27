require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; module CustomHandler; module CalendarManager; class CalendarUploadParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def self.valid_file? filename
    ['.XLS', '.XLSX', '.CSV'].include? File.extname(filename.upcase)
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("Calendar Management") && user.company.master?
  end

  def can_view? user
    self.class.can_view? user
  end

  def process user
    errors = []
    foreach(@custom_file, skip_headers: true, skip_blank_lines: true) do |row, row_number|
        process_row(row, row_number, errors)
    rescue StandardError => e
        errors << "Failed to process calendar #{row[1]} - #{row[0]} due to the following error: #{e.message}"
    end
    message_to_user user, errors
  end

  private

  def process_row row, row_number, errors
    calendar_type = row[0]
    calendar_year = integer_value row[1]
    event_label = row[4]
    event_date = date_value row[3]
    company_id = nil

    if event_date.blank? || calendar_year.blank? || calendar_type.blank?
      return errors << "Required value missing on line #{(row_number + 1)}."
    end

    if row[2].present?
      begin
        company_id = Company.where(name: row[2]).first.id
      rescue NoMethodError
        return errors << "Company could not be found on line #{(row_number + 1)}."
      end
    end

    calendar = Calendar.where(company_id: company_id, year: calendar_year, calendar_type: calendar_type).first_or_initialize
    calendar.save!
    CalendarEvent.where(event_date: event_date, calendar_id: calendar.id, label: event_label).first_or_initialize.save!

    errors
  end

  def message_to_user user, errors
    body = "Calendar upload processing for file #{@custom_file.attached_file_name} is complete."
    subject = "File Processing Complete"

    if errors.present?
      body += "\n\n#{errors.join("\n")}"
      subject += " With Errors"
    end

    user.messages.create(subject: subject, body: body)
  end
end; end; end; end
