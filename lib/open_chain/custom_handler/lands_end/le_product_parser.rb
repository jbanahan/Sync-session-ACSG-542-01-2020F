require 'open_chain/custom_handler/custom_file_csv_excel_parser'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/parser_support'

module OpenChain; module CustomHandler; module LandsEnd; class LeProductParser
  include OpenChain::CustomHandler::CustomFileCsvExcelParser
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::ParserSupport

  attr_accessor :updater

  def initialize custom_file
    @custom_file = custom_file
    @updater = Updater.new
  end

  def self.valid_file? file
    [".xls", ".xlsx", ".csv"].include? File.extname(file).to_s.downcase
  end

  def self.can_view? user
    MasterSetup.get.custom_feature?("Lands End Parts") && user.company.master? && user.edit_products?
  end

  def can_view? user
    self.class.can_view? user
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:prod_part_number, :prod_short_description]
  end

  def us
    @us ||= Country.find_by iso_code: "US"
    raise "US missing from countries table" unless @us
    @us
  end

  def importer
    @importer ||= Company.find_by system_code: "LANDS1"
    raise "'LANDS1' importer not found!" unless @importer
    @importer
  end

  def process user
    begin
      process_file @custom_file, user
      user.messages.create subject: "File Processing Complete", body: "Land's End Product Upload processing for file #{@custom_file.attached_file_name} is complete."
    rescue => e
      user.messages.create subject: "File Processing Complete With Errors", body: "Unable to process file #{@custom_file.attached_file_name} due to the following error:<br>#{e.message}"
    end
    nil
  end

  def process_file custom_file, user
    cache = []
    current_style_nbr = nil
    foreach(custom_file, skip_headers: true) do |r|
      row = r.map(&:presence)
      if row[0] != current_style_nbr && current_style_nbr.present?
        process_part cache, user
        cache = [row]
      else
        cache << row
      end
      current_style_nbr = row[0]
    end
    process_part cache, user
  end

  def process_part cache, user
    @updater.reset
    multi_tariff = cache.transpose[10].uniq.count > 1
    first_row = cache.first
    part_no = first_row[0].to_i.to_s
    uid = "LANDS1-#{part_no}"
    new_tariff = first_row[10]
    
    find_or_create_product(uid) do |prod|
      updater.set prod, part_no, cdef: cdefs[:prod_part_number]
      updater.set prod, first_row[1], cdef: cdefs[:prod_short_description]
      classi = prod.classifications.find{ |cl| cl.country_id == us.id } || prod.classifications.build(country: us)
      # If there are any manually-added tariffs then start over
      if classi.tariff_records.length > 1
        classi.tariff_records.destroy_all
        updater.set_changed
      end      
      tariff = classi.tariff_records.first
      # If there's more than one, don't record any of them
      if multi_tariff
        if tariff
          tariff.destroy
          updater.set_changed
        end
      else
        if tariff
          updater.set tariff, new_tariff, attrib: :hts_1
        else
          classi.tariff_records.build hts_1: new_tariff
          updater.set_changed
        end
      end     
      if updater.changed?
        prod.save!
        prod.create_snapshot user, nil, "LeProductParser"
      end
    end
  end

  def find_or_create_product uid
    product = nil
    Lock.acquire("Product-#{uid}") do 
      product = Product.where(importer_id: importer.id, unique_identifier: uid).first_or_initialize
      unless product.persisted?
        updater.set_changed
        product.save!
      end
    end

    Lock.with_lock_retry(product) do 
      yield product
    end
  end

end; end; end; end
