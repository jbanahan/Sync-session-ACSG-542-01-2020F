require 'open_chain/polling_job'
require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_entry_xml_generator'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_entry_xml_generator'
require 'open_chain/custom_handler/vandegrift/kewill_entry_load_shipment_comparator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillMultiShipmentEntryXmlGenerator
  include OpenChain::PollingJob
  include OpenChain::FtpFileSupport
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.run_schedulable opts
    raise "Job must be configured with at least one value for the 'importer_system_code' key." if opts["importer_system_code"].blank?
    self.new.find_generate_and_send opts
  end

  attr_reader :xml_generator

  def initialize generator = OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator.new
    @xml_generator = generator
  end

  def find_generate_and_send opts
    poll do |last_run, end_time|
      shipments = find_shipments(last_run, opts["importer_system_code"])
      group_shipments_by_masterbill(shipments).each_pair do |master_bill, shipments|
        begin
          generate_and_send(shipments)
        rescue => e
          # Don't let one group of potentially bad shipments stop others from executing
          raise e if MasterSetup.test_env?

          e.log_me ["Master Bill: #{shipments.first.master_bill_of_lading}"]
        end
      end
    end
    
  end

  def generate_and_send shipments
    sorted_shipments = sort_shipments_for_generation(shipments)
    ActiveRecord::Base.transaction do 
      sync_records = shipment_sync_records(shipments)
      xml_generator.generate_xml_and_send sorted_shipments, sync_records: shipment_sync_records(shipments)
      mark_sync_records_as_synced sync_records
    end
  end

  def sort_shipments_for_generation shipments
    # By default, we're just going to sort by the importer reference and then fall back to created_at to keep a 
    # consistent order.
    shipments.sort_by {|s| [s.importer_reference, s.created_at] }
  end

  def shipment_sync_records shipments
    sync_records = []
    shipments.each do |s|
      sr = s.sync_records.find {|sr| sr.trading_partner == OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER }
      if sr.nil?
        sr = s.sync_records.build trading_partner: OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER
      end

      sync_records << sr
    end
    sync_records
  end

  def mark_sync_records_as_synced sync_records
    sync_records.each do |sr|
      # We may have some shipments that were already sent in here, don't update these...it'll help potential debugging scenarios
      # to be able to track the progress of the master bill.
      sr.update_attributes! sent_at: Time.zone.now, confirmed_at: (Time.zone.now + 1.minute) if sr.sent_at.nil?
    end
  end

  def find_shipments updated_after, importer_system_codes
    # Find all shipments for the given importers that have non-null entry prepared dates and sent_at date on the sync record is null.
    s = Shipment.joins(:importer).
      where(companies: {system_code: Array.wrap(importer_system_codes)}).
      where("shipments.updated_at >= ?", updated_after).
      where("shipments.canceled_date IS NULL").
      joins(:country_import).
      where(countries: {iso_code: "US"}).
      where("master_bill_of_lading IS NOT NULL AND master_bill_of_lading <> ''").
      joins("LEFT OUTER JOIN sync_records sr ON shipments.id = sr.syncable_id AND sr.syncable_type = 'Shipment' AND sr.trading_partner = '#{OpenChain::CustomHandler::Vandegrift::KewillEntryLoadShipmentComparator::TRADING_PARTNER}'").
      joins("INNER JOIN custom_values cv ON shipments.id = cv.customizable_id AND cv.customizable_type = 'Shipment' AND cv.datetime_value IS NOT NULL AND cv.custom_definition_id = #{cdefs[:shp_entry_prepared_date].id}").
      where("sr.sent_at IS NULL").to_a
  end

  def cdefs
    self.class.prep_custom_definitions([:shp_entry_prepared_date])
  end

  def group_shipments_by_masterbill shipments
    grouped_shipments = Hash.new {|h, k| h[k] = [] }
    shipments.each {|s| grouped_shipments[s.master_bill_of_lading] << s }

    all_matching_shipments = {}

    grouped_shipments.values.each do |shipments|
      matching_shipments = shipments
      matching_shipments.push *find_other_matching_shipments(shipments)
      all_matching_shipments[shipments.first.master_bill_of_lading] = matching_shipments
    end

    all_matching_shipments
  end

  def find_other_matching_shipments shipments
    # Find any other shipment that shares the same master bill as the given shipments AND has an Entry Prepared Date value
    Shipment.where(importer_id: shipments.first.importer_id, master_bill_of_lading: shipments.first.master_bill_of_lading).
      where("shipments.id NOT IN (?)", shipments.map {|s| s.id }).
      joins("INNER JOIN custom_values cv ON shipments.id = cv.customizable_id AND cv.customizable_type = 'Shipment' AND cv.datetime_value IS NOT NULL AND cv.custom_definition_id = #{cdefs[:shp_entry_prepared_date].id}").
      joins(:country_import).
      where(countries: {iso_code: "US"}).
      to_a
  end

end; end; end; end