require 'open_chain/entity_compare/uncancelled_shipment_comparator'
require 'open_chain/ftp_file_support'
require 'open_chain/custom_handler/vandegrift/kewill_shipment_entry_xml_generator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillEntryLoadShipmentComparator
  extend OpenChain::EntityCompare::UncancelledShipmentComparator
  include OpenChain::EntityCompare::ComparatorHelper
  include OpenChain::FtpFileSupport

  TRADING_PARTNER ||= "Kewill Entry"

  def self.accept? snapshot
    accept = super
    return false unless accept

    return has_entry_load_configured? snapshot.recordable
  end

  # This method primariy exists as an override point for extending classes that might be hardcoded 
  # to one or two importer accounts
  def self.has_entry_load_configured? shipment
    kewill_customer_number = shipment.importer.try(:kewill_customer_number)
    return false if kewill_customer_number.blank?

    ci_load_data.keys.include? kewill_customer_number
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Really, all we're doing here is finding the shipment, seeing if it's been synced already.
    # If not, then we're syncing it..doing it this way allows for a very easy screen edits and resend
    # should we move away from the straight fenix generator process
    shipment = Shipment.where(id: id).first
    if shipment
      self.new.compare(shipment, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    end
  end

  def compare shipment, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Don't send any shipments until they're marked as being prepared (spelling error is, unfortunately, required)
    cd = CustomDefinition.where(cdef_uid: "shp_entry_pepared").first
    raise "'Entry Prepared Date' custom field does not exist." unless cd
    return if cd.nil?

    return unless shipment.custom_value(cd)

    Lock.with_lock_retry(shipment) do
      sr = shipment.sync_records.where(trading_partner: trading_partner(shipment)).first_or_initialize
      return unless send_xml?(shipment, sr, cd, old_bucket, old_path, old_version, new_bucket, new_path, new_version)

      generate_and_send shipment, sr
      sr.sent_at = Time.zone.now
      sr.confirmed_at = (sr.sent_at + 1.minute)
      sr.save!
    end
  end

  def generate_and_send shipment, sync_record
    xml = invoice_generator(shipment.importer.kewill_customer_number).generate_xml shipment
    Tempfile.open(["ci_load_#{shipment.reference}_", ".xml"]) do |file|
      xml.write file
      file.flush

      ftp_sync_file file, sync_record, ecs_connect_vfitrack_net("kewill_edi/to_kewill")
    end
  end

  def send_xml? shipment, sr, custom_definition, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # We want to send the xml if the Entry Prepared date was updated OR if the Sync Record's Sent At was blanked.
    sr.sent_at.nil? || any_root_value_changed?(old_bucket, old_path, old_version, new_bucket, new_path, new_version, [custom_definition.model_field_uid])
  end

  def trading_partner shipment
    TRADING_PARTNER
  end

  def invoice_generator kewill_customer_number
    generator_string = self.class.ci_load_data[kewill_customer_number]
    if generator_string.blank?
      return OpenChain::CustomHandler::Vandegrift::KewillShipmentEntryXmlGenerator.new
    else
      # This assumes the generator class has already been required...it should always be by virtue
      # of the snapshot comparator always running in a delayed job queue (which loads every class/file 
      # in lib)
      return generator_string.constantize.new
    end
  end

  def self.ci_load_data
    DataCrossReference.get_all_pairs(DataCrossReference::SHIPMENT_ENTRY_LOAD_CUSTOMERS)
  end

  def sync_record shipment
    tp = trading_partner(shipment)
    sr = shipment.sync_records.find {|sr| sr.trading_partner == tp}
    if sr.nil?
      sr = shipment.sync_records.build trading_partner: tp
    end
    sr
  end
 
end; end; end; end;