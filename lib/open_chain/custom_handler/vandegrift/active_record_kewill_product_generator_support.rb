require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_product_generator_support'

# This module does the bulk of the work around syncing product data to Customs Management (Kewill) via straight ActiveRecord objects
#
# The only thing your including class must do is implement a build_data method that receives a product
# object and returns a populated ProductData object (see KewillProductGeneratorSupport)
#
module OpenChain; module CustomHandler; module Vandegrift; module ActiveRecordKewillProductGeneratorSupport
  extend ActiveSupport::Concern
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::Vandegrift::KewillProductGeneratorSupport

  # This method will continuously build and send an XML file as long as there are
  # at least max_products_per_file records written to the file.
  def sync_xml importers, trading_partner: "CMUS", max_products_per_file: 500
    record_count = 0
    begin
      products = find_products(importers, trading_partner, max_products_per_file)
      generate_and_send_products(products, trading_partner)
    end while record_count >= max_products_per_file

    nil
  end

  def generate_and_send_products products, trading_partner
    products = Array.wrap(products)
    return unless products.length > 0

    make_xml_file(products, trading_partner) do |file, sync_records|
      ftp_sync_file(file, sync_records, ftp_credentials)
      sync_records.each(&:save!)
    end

    nil
  end

  # Returns all the product records that should be synced
  def find_products importers, trading_partner, max_products_per_file
    query = Product.where(importer: importers)
                   .where("products.inactive = 0 OR products.inactive IS NULL")
                   .joins(classifications: [:tariff_records])
                   .where(classifications: { country: _us })
                   .where("tariff_records.hts_1 IS NOT NULL AND LENGTH(tariff_records.hts_1) >= 8")
                   .limit(max_products_per_file)
                   .order("products.id")
                   .uniq

    query = query.joins(Product.join_clause_for_need_sync(trading_partner))
    query = query.where(Product.where_clause_for_need_sync)

    query
  end

  # Builds the product data, writes the data to an XML file, generates sync records and then
  # yields the tempfile and sync records to the caller.
  def make_xml_file products, trading_partner
    Tempfile.open(["ProductSync-#{Time.zone.now.strftime("%Y%m%d%H%M%S")}", ".xml"]) do |temp|
      sync_records = []
      document, parent = xml_document_and_root_element

      products.each do |product|
        preload_product(product)
        write_tariff_data_to_xml(parent, build_data(product))
        sync_records << set_sync_record(product, trading_partner)
      end
      write_xml document, temp
      temp.flush
      temp.rewind

      yield temp, sync_records
    end

    nil
  end

  # Finds or creates a sync record for the given product / trading partner
  def set_sync_record product, trading_partner
    sync = product.sync_records.where(trading_partner: trading_partner).first
    if sync.nil?
      sync = product.sync_records.build trading_partner: trading_partner
    end
    sync.sent_at = Time.zone.now
    sync.confirmed_at = Time.zone.now + 1.minute
    sync
  end

  # Preloads all associations for a single product
  def preload_product product
    @preloaded_associations ||= preload_associations
    return if @preloaded_associations.nil?

    ActiveRecord::Associations::Preloader.new.preload(product, @preloaded_associations)
    nil
  end

  # The AR associations to preload for a single product.
  # This method can be overriden to preload another distinct set of associations.
  # You can also disable preloading by making this method return nil.
  def preload_associations
    [classifications: [tariff_records: [:custom_values]]]
  end

  def _us
    @country ||= Country.where(iso_code: "US").first
    raise "Failed to find US country" if @country.nil?

    @country
  end
end; end; end; end
