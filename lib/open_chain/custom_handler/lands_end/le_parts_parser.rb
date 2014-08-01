require 'open_chain/xl_client'
require 'open_chain/custom_handler/lands_end/le_custom_definition_support'

module OpenChain; module CustomHandler; module LandsEnd; class LePartsParser
  extend OpenChain::IntegrationClientParser
  include OpenChain::CustomHandler::LandsEnd::LeCustomDefinitionSupport

  def self.integration_folder
    ["/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_lands_end_products"]
  end

  def self.process_from_s3 bucket, key, opts = {}
    xl_client = OpenChain::XLClient.new key, bucket: bucket
    parser = self.new xl_client
    parser.process_file
  end

  def initialize xl_client, system_code = "LERETURNS"
    @xl_client = xl_client
    @cdefs = self.class.prep_custom_definitions [:part_number, :suffix_indicator, :exception_code, :suffix, :comments]
    @importer = Company.where(system_code: system_code).importers.first
    raise "Invalid importer system code #{system_code}." unless @importer
  end

  def process_file
    counter = 0
    xl_client.all_row_values do |row|
      # Skip the first row, it's the header
      next if (counter+=1) == 1
      process_product_line(stringify(row))
    end
  end

  def process_product_line row
    @us ||= Country.where(iso_code: "US").first

    # The unique identifier for the products has to be the first 4 columns of the file
    id = unique_identifier @importer.system_code, row
    prod = Product.where(unique_identifier: id, importer_id: @importer.id).first_or_create!
    Lock.with_lock_retry(prod) do 
      us_classification = prod.classifications.where(country_id: @us.id).first_or_create!
      tariff = us_classification.tariff_records.where(classification_id: us_classification.id).first_or_create!
      tariff.hts_1 = row[14]
      tariff.save!

      prod.update_custom_value! @cdefs[:part_number], row[0]
      prod.update_custom_value! @cdefs[:suffix_indicator], row[1]
      prod.update_custom_value! @cdefs[:exception_code], row[2]
      prod.update_custom_value! @cdefs[:suffix], row[3]
      prod.update_custom_value! @cdefs[:comments], [row[15], row[16]].select {|v| !v.blank? }.join(" | ")


      factory = Address.where(company_id: @importer.id, system_code: row[4]).first_or_create!(
        name: row[5], line_1: row[6], line_2: row[7], line_3: row[8], city: row[9], 
        country: Country.where(iso_code: row[12]).first
      )

      prod.factories << factory unless prod.factories.include?(factory)
    end
    prod
  end

  private
    # For testing/stub'ing purposes
    def xl_client
      @xl_client
    end

    def unique_identifier customer_number, row
      id = customer_number
      (0..3).each do |x|
        id += ("-" + (row[x].blank? ? " " : row[x].strip))
      end
      id
    end

    def stringify row
      # there should be no actual numbers in the file (no values, etc.)
      row.collect do |r|
        OpenChain::XLClient.string_value(r).strip
      end
    end

end; end; end; end
