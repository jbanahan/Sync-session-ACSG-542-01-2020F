require 'open_chain/custom_handler/csv_excel_parser'

module OpenChain; class DataCrossReferenceUploadPreprocessor
  extend OpenChain::CustomHandler::CsvExcelParser
  
  def self.preprocessors
    {
      "none" => lambda { |key, value| {key: key, value: value} },
      "asce_mid" => lambda { |key, value| {key: key, value: date_value(value).try(:strftime, "%Y-%m-%d")} }
    }
  end
end; end