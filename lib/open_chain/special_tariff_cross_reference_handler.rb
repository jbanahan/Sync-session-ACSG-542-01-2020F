require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/report/report_helper'

# This file handles both uploads and downloads of Special Tariffs Cross Reference
module OpenChain; class SpecialTariffCrossReferenceHandler
  include OpenChain::Report::ReportHelper
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file=nil
    @custom_file ||= custom_file
  end

  def self.send_tariffs user_id
    self.new.send_tariffs user_id
  end

  def send_tariffs user_id
    user = User.find(user_id)
    workbook, sheet = create_workbook_and_worksheet
    SpecialTariffCrossReference.order('special_tariff_type DESC, hts_number DESC').each do |tariff|
      workbook.add_body_row sheet, [tariff.hts_number, tariff.special_hts_number, tariff.country_origin_iso, tariff.import_country_iso,
                                    tariff.effective_date_start, tariff.effective_date_end, tariff.priority,
                                    tariff.special_tariff_type, tariff.suppress_from_feeds?]
    end

    report = xlsx_workbook_to_tempfile(workbook, "Special Tariffs", file_name: "Special Tariffs for #{Time.zone.now.strftime("%m/%d/%Y")}")
    body = "Attached is the list of special tariffs for #{Time.zone.now.strftime("%m/%d/%Y")}"
    OpenMailer.send_simple_html([user.email], "Special Tariffs Current as of #{Time.zone.now.strftime("%m/%d/%Y")}", body, report).deliver_now
  end


  def process user, parameters

    recoverable_errors = []

    begin
      file_name = @custom_file.attached_file_name
      ext = File.extname file_name

      raise ArgumentError, "Only XLS, XLSX, and CSV files are accepted." unless [".CSV", ".XLS", ".XLSX"].include? ext.upcase

      process_rows @custom_file, recoverable_errors

      if recoverable_errors.empty?
        user.messages.create!(subject: "File Processing Complete", body: "Special Tariff Cross Reference upload for file #{file_name} is complete")
      else
        user.messages.create!(subject: 'File Processing Complete With Errors',
                             body: "Special Tariff Cross Reference uploader generated errors on the following row(s): #{recoverable_errors.join(', ')}. Missing or invalid HTS")

      end
    rescue => e
      user.messages.create!(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{file_name} due to the following error:<br>#{e.message}")
    end
  end

  def create_workbook_and_worksheet
    wb = XlsxBuilder.new
    sheet1 = wb.create_sheet("Special Tariffs")
    wb.add_body_row sheet1, ['HTS Number', 'Special HTS Number', 'Origin Country ISO', 'Import Country ISO',
                             'Effective Date Start', 'Effective Date End', 'Priority', 'Special Tariff Type',
                             'Suppress From Feeds']
    [wb, sheet1]
  end

  private

  def process_row row, row_number
    stcr = SpecialTariffCrossReference.where(hts_number: row[0]).first_or_initialize
    stcr.special_hts_number = text_value row[1]
    stcr.country_origin_iso = text_value row[2]
    stcr.import_country_iso = text_value row[3]
    stcr.effective_date_start = date_value row[4]
    stcr.effective_date_end = date_value row[5]
    stcr.priority = integer_value row[6]
    stcr.special_tariff_type = text_value row[7]
    stcr.suppress_from_feeds = boolean_value row[8].to_s[0]
    stcr.save
  end

  def process_rows custom_file, errors
    foreach(custom_file, skip_blank_lines:true, skip_headers: true) do |row, row_number|
      unless row[0].present?
        errors << row_number
        next
      end

      process_row row, row_number
    end
  end

end; end
