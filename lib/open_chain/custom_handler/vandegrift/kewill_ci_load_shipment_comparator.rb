require 'open_chain/entity_compare/shipment_comparator'
require 'open_chain/entity_compare/comparator_helper'
require 'open_chain/custom_handler/vandegrift/kewill_generic_shipment_ci_load_generator'

module OpenChain; module CustomHandler; module Vandegrift; class KewillCiLoadShipmentComparator
  extend OpenChain::EntityCompare::ShipmentComparator
  extend OpenChain::EntityCompare::ComparatorHelper

  def self.accept? snapshot
    accept = super
    return false unless accept

    kewill_customer_number = snapshot.try(:recordable).try(:importer).try(:kewill_customer_number)
    return false if kewill_customer_number.blank?

    shipment_ci_load_customers = ci_load_data.keys
    shipment_ci_load_customers.include? kewill_customer_number
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
      cd = CustomDefinition.where(cdef_uid: "shp_invoice_prepared_date").first
      raise "'Invoice Prepared Date' custom field does not exist." unless cd
      return if cd.nil?

      return unless shipment.custom_value(cd)

      Lock.with_lock_retry(shipment) do
        sr = shipment.sync_records.where(trading_partner: "CI LOAD").first_or_initialize
        # By checking for a sent_at rather than just the existence of a record we can use the screen
        # to resend (since it blanks sent_at)
        if send_xml?(shipment, sr, cd, old_bucket, old_path, old_version, new_bucket, new_path, new_version)
          invoice_generator(shipment.importer.kewill_customer_number).generate_and_send shipment
          sr.sent_at = Time.zone.now
          sr.confirmed_at = (sr.sent_at + 1.minute)
          sr.save!
        end
      end
    end
  end

  def self.send_xml? shipment, sr, custom_definition, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    # We want to send the xml if the Entry Invoiced Prepared Date was updated OR if the Sync Record's Sent At was blanked.
    sr.sent_at.nil? || any_root_value_changed?(old_bucket, old_path, old_version, new_bucket, new_path, new_version, [custom_definition.model_field_uid])
  end

  def self.invoice_generator kewill_customer_number
    generator_string = ci_load_data[kewill_customer_number]
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