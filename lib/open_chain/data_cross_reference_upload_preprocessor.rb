require 'open_chain/custom_handler/csv_excel_parser'

module OpenChain; class DataCrossReferenceUploadPreprocessor
  extend OpenChain::CustomHandler::CsvExcelParser

  def self.preprocessors
    {
      "none" => lambda { |key, value| {key: text_value(key), value: text_value(value) } },
      "asce_mid" => lambda { |key, value| {key: key, value: date_value(value).try(:strftime, "%Y-%m-%d")} },
      "spi_available_country_combination" => lambda { |key, value| {key: DataCrossReference.make_compound_key(key.to_s.strip, value.to_s.strip), value: "X"} }
    }
  end
end; end