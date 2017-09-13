require 'open_chain/entity_compare/shipment_comparator'
require 'open_chain/custom_handler/vandegrift/kewill_generic_shipment_ci_load_generator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCiLoadShipmentComparator
  extend OpenChain::EntityCompare::ShipmentComparator

  def self.accept? snapshot
    accept = super
    return false unless accept

    alliance_customer_number = snapshot.try(:recordable).try(:importer).try(:alliance_customer_number)
    return false if alliance_customer_number.blank?

    shipment_ci_load_customers = ci_load_data.keys
    shipment_ci_load_customers.include? alliance_customer_number
  end

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # Really, all we're doing here is finding the shipment, seeing if it's been synced already.
    # If not, then we're syncing it..doing it this way allows for a very easy screen edits and resend
    # should we move away from the straight fenix generator process
    shipment = Shipment.where(id: id).first
    if shipment
      # Don't send cancelled shipments
      return unless shipment.canceled_date.nil?

      # Don't send any shipments until they're marked as being prepared
      cd = CustomDefinition.where(cdef_uid: "shp_invoice_prepared").first
      raise "'Invoice Prepared' custom field does not exist." unless cd
      return if cd.nil?

      return unless shipment.custom_value(cd)

      Lock.with_lock_retry(shipment) do
        sr = shipment.sync_records.where(trading_partner: "CI LOAD").first_or_initialize
        # By checking for a sent_at rather than just the existence of a record we can use the screen
        # to resend (since it blanks sent_at)
        if sr.sent_at.nil?
          invoice_generator(shipment.importer.alliance_customer_number).generate_and_send shipment
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (sr.sent_at + 1.minute)
          sr.save!
        end
      end
    end
  end

  def self.invoice_generator alliance_customer_number
    generator_string = ci_load_data[alliance_customer_number]
    if generator_string.blank?
      return OpenChain::CustomHandler::Vandegrift::KewillGenericShipmentCiLoadGenerator.new
    else
      # This assumes the generator class has already been required...it should always be by virtue
      # of the snapshot comparator always running in a delayed job queue (which loads every class/file 
      # in lib)
      return generator_string.constantize.new
    end
  end

  def self.ci_load_data
    DataCrossReference.get_all_pairs(DataCrossReference::SHIPMENT_CI_LOAD_CUSTOMERS)
  end
 
end; end; end; end;