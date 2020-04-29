require 'open_chain/custom_handler/custom_file_csv_excel_parser'

module OpenChain; class FiscalMonthUploader
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def process user, parameters # company_id required
    check_extension(File.extname(@custom_file.path))
    errors = []
    foreach(@custom_file, skip_blank_lines:true) do |row, row_number|
      next if row_number == 0
      process_row(row, row_number, parameters[:company_id], errors)
    end
    errors_to_user(user, errors)
  end

  private

  def check_extension ext
    if ![".xls", ".xlsx", ".csv"].include? ext.downcase
      raise ArgumentError, "Only XLS, XLSX, and CSV files are accepted."
    end
  end

  def process_row row, row_number, company_id, errors
    fm = nil
    Lock.acquire("FM-#{company_id}-#{row[0]}-#{row[1]}") do
      fm = FiscalMonth.where(company_id: company_id, year: row[0], month_number: row[1])
                .first_or_initialize(company_id: company_id, year: row[0], month_number: row[1])
      update_fiscal_month! fm, row, row_number, errors
    end
  end

  def update_fiscal_month! fm, row, row_number, errors
    begin
      fm.update_attributes!(start_date: Date.parse(row[2].to_s), end_date: Date.parse(row[3].to_s))
    rescue ArgumentError
      errors << (row_number + 1).to_s
    end
  end

  def errors_to_user user, errors
    if errors.presence
      user.messages.create!(subject: "Fiscal-month uploader generated errors",
                            body: "Fiscal-month uploader generated errors on the following row(s): #{errors.join(', ')}. Check the date format.")
    end
  end

end; end