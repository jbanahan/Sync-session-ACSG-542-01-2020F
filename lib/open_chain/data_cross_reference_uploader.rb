require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/data_cross_reference_upload_preprocessor'

module OpenChain; class DataCrossReferenceUploader
  include OpenChain::CustomHandler::CustomFileCsvExcelParser

  def initialize custom_file
    @custom_file = custom_file
  end

  def process user, parameters #requires cross_reference_type
    recoverable_errors = []
    begin
      validate_file @custom_file
      xref_type = parameters[:cross_reference_type]
      xref_hsh = DataCrossReference.xref_edit_hash(user)[xref_type]
      process_rows @custom_file, xref_hsh, xref_type, recoverable_errors
    rescue => e
      user.messages.create(:subject=>"File Processing Complete With Errors", :body=>"Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}")
    end
    complete_successfully user, recoverable_errors
  end

  private

  def complete_successfully user, recoverable_errors
    if recoverable_errors.empty?
      user.messages.create subject: "File Processing Complete", body: "Cross-reference upload for file #{@custom_file.attached_file_name} is complete."
    else
      recoverable_errors_to_user(user, recoverable_errors)
    end
  end

  def validate_file custom_file
    bad_extension_error = self.class.check_extension(@custom_file.attached_file_name)
    raise ArgumentError, bad_extension_error if bad_extension_error
  end

  def self.check_extension file_name
    ext = File.extname file_name
    valid = [".CSV", ".XLS", ".XLSX"].include? ext.upcase
    !valid ? "Only XLS, XLSX, and CSV files are accepted." : nil 
  end
  
  def process_rows custom_file, xref_hsh, xref_type, errors
    co = DataCrossReference.company_for_xref xref_hsh
    foreach(custom_file, skip_blank_lines:true) do |row, row_number| 
      next if row_number == 0
      process_row(row, row_number, co.try(:id), xref_hsh, xref_type, errors)
    end
  end

  def process_row row, row_number, company_id, xref_hsh, xref_type, errors
    success = DataCrossReference.preprocess_and_add_xref! xref_type, row[0], row[1], company_id
    errors << row_number unless success 
  end

  def recoverable_errors_to_user(user, errors)
    if errors.presence
      user.messages.create!(subject: "File Processing Complete With Errors", 
                            body: "Cross-reference uploader generated errors on the following row(s): #{errors.join(', ')}. Missing or invalid field.")
    end
  end

end; end